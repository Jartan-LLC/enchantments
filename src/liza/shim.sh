#!/bin/bash
# `liza` on PATH. Every subcommand goes to the real binary; `init` is wrapped so
# Liza's activation lands in this clone's local-scope files instead of the
# committed .claude/settings.json and the user-wide ~/.claude/CLAUDE.md.
# Upstream tracking this: liza-mas/liza issue 164.
# shellcheck source-path=SCRIPTDIR

set -uo pipefail

real_liza="$HOME/.liza/libexec/liza"

# Global flags can precede the subcommand; -C/--project-root and
# --update-channel take a value.
subcommand="" project_root=""
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  case "${args[i]}" in
    -C | --project-root)
      project_root="${args[i + 1]:-}"
      ((i++))
      ;;
    --project-root=*) project_root="${args[i]#*=}" ;;
    --update-channel) ((i++)) ;;
    -*) ;;
    *)
      subcommand="${args[i]}"
      break
      ;;
  esac
done
[ "$subcommand" = init ] || exec "$real_liza" "$@"
# --help writes nothing, so it goes straight to Liza.
for arg in "$@"; do
  case "$arg" in -h | --help) exec "$real_liza" "$@" ;; esac
done

top=$(git -C "${project_root:-.}" rev-parse --show-toplevel) || exit 1
claude_dir="$top/.claude"
shared_settings="$claude_dir/settings.json"
local_settings="$claude_dir/settings.local.json"
held_settings="$claude_dir/settings.json.liza-shim-held"
backup_settings="$claude_dir/settings.local.json.liza-shim-backup"
global_contract="$HOME/.claude/CLAUDE.md"

here=$(dirname "$(readlink -f "$0")")
# shellcheck source=activation-lib.sh
source "$here/activation-lib.sh"

# Refuses this init with $liza_refused, which never reports a failed init, so
# a caller can tell the two apart. The message also goes to the file
# $LIZA_SHIM_REFUSAL names, when set, for a caller that records it.
refuse() { # message...
  echo "liza shim: $*" >&2
  [ -z "${LIZA_SHIM_REFUSAL:-}" ] || printf '%s\n' "$*" >"$LIZA_SHIM_REFUSAL"
  exit "$liza_refused"
}

# Takes a lock directory, or exits: refusing when another holder has it.
take_lock() { # dir holder
  mkdir "$1" 2>/dev/null && return 0
  [ -d "$1" ] && refuse "$2 holds $1; remove it with rmdir if none is running."
  echo "liza shim: can't create $1" >&2
  exit 1
}

# --- Lock the clone for this init ---
# mkdir is atomic: a second concurrent init would otherwise swap the
# already-swapped files. Held until the record is written, so a deactivate or
# another init can't interleave. The repo's lock keeps two worktrees from
# activating at once. Each is released only by the run that took it.
# Checked before any git path is built: git paths need 2.31.
old_git="git can't list this repo's worktrees, so another one's activation"
old_git+=" can't be ruled out; Liza needs git 2.36 or later."
git -C "$top" worktree list --porcelain -z >/dev/null 2>&1 \
  || refuse "$old_git"
lock="$claude_dir/.liza-shim.lock"
repo_lock="$(git -C "$top" rev-parse --path-format=absolute \
  --git-common-dir)/liza-activation.lock"
have_lock=false have_repo_lock=false
unlock() {
  if $have_lock; then rmdir "$lock"; fi
  if $have_repo_lock; then rmdir "$repo_lock"; fi
}
trap unlock EXIT
trap 'exit 130' INT TERM
mkdir -p "$claude_dir"
take_lock "$lock" "another init"
have_lock=true
take_lock "$repo_lock" "another worktree's init"
have_repo_lock=true
# A repo's worktrees share its git hooks and exclude file.
active=$(other_activation "$top")
case $? in
  0) refuse "Liza is active in $active, another worktree of this repo; run" \
    "liza-deactivate there first." ;;
  2) refuse "$old_git" ;;
esac
if [ -e "$held_settings" ]; then
  refuse "$held_settings exists from an interrupted init; move it back to" \
    "settings.json (and any settings.local.json.liza-shim-backup back to" \
    "settings.local.json) first."
fi

# Liza reads the toolchain's LIZA_ENABLE_* gates at init time, and the shell
# running init (a script, /onboard, Liza's operator agent) may not have loaded
# them.
if [ -d "$liza_toolchain" ] && [ -f "$HOME/.liza/toolchain/env.sh" ]; then
  # shellcheck source=/dev/null
  source "$HOME/.liza/toolchain/env.sh"
fi
# Refused up front, naming the hook, rather than left to fail inside init.
own_hook=$(own_index_hook "$top")
case $? in
  0) refuse "the repo has its own $own_hook git hook, which Liza won't" \
    "replace with its code-index hook." ;;
  2) refuse "git can't locate this repo's hooks, so Liza's code-index hooks" \
    "can't be checked." ;;
esac

# --- Snapshot the state before init ---
had_global_contract=false
if [ -e "$global_contract" ] || [ -L "$global_contract" ]; then
  had_global_contract=true
fi
# Untracked paths at the top level and in .claude/, the area activation
# watches, minus the two settings files activation manages itself.
# grep runs under LC_ALL=C here to match bytes: in a UTF-8 locale it would
# drop a name that isn't valid UTF-8, with a warning.
init_area_untracked() { # ls-files-options...
  git -C "$top" ls-files -z --others "$@" -- .claude ':(glob)*' \
    | LC_ALL=C grep -z -v -x -F -e .claude/settings.local.json \
      -e .claude/settings.json
}
# The ignored ones activation may overwrite: those at the top level, in
# .claude/ itself and under .claude/hooks/, where Liza documents that init
# writes files for Claude, and the entries in .claude/skills/, where the shim
# replaces a symlink with a link to Liza's skill.
# Every top-level one counts: Liza documents no closed list of the files init
# writes there.
# The rest, such as a workspace folder, would only slow the backup, which
# fingerprints and copies each file.
init_write_ignored() {
  init_area_untracked --ignored --exclude-standard \
    | LC_ALL=C grep -z -x -E \
      '[^/]*|\.claude/[^/]*|\.claude/hooks/.*|\.claude/skills/[^/]*'
}
# A file init creates counts as its own whether git shows it or an exclude line
# hides it. Hidden ones are listed across the whole area, not only
# init_write_ignored's paths, so one created anywhere in it is recorded.
shown_untracked() {
  git -C "$top" ls-files -z --others --exclude-standard
}
hidden_untracked() {
  init_area_untracked --ignored --exclude-standard
}
untracked_before=()
read_top_paths untracked_before "$top" \
  < <(shown_untracked && hidden_untracked)
git_dir=$(git -C "$top" rev-parse --absolute-git-dir)
hooks_dir=$(git_path "$top" hooks)
exclude_file=$(git_path "$top" info/exclude)
record_dir=$(record_dir_of "$top")
record="$record_dir/activation.json"
recorded_files=()
[ -f "$record" ] && mapfile -t recorded_files \
  < <(record_query recorded_paths "$record" 2>/dev/null)
recorded_before=$(fingerprint "${recorded_files[@]}")
git_before=$(fingerprint "$git_dir"/liza* "$hooks_dir"/*)
exclude_before=$(cat "$exclude_file" 2>/dev/null)
pre_settings=$(cat "$local_settings" 2>/dev/null || echo '{}')

# --- Back up the user's files init may clobber ---
# Liza's init, and the skill links this shim makes after it, overwrite or
# remove an untracked file of the user's at a path they write to. Each such
# candidate (file or symlink) is copied to originals/ first, and the copy stays
# only if the file is changed. Liza's own files are skipped, and so is a file
# an earlier activation already saved: that first copy is the user's.
originals="$record_dir/originals"
mapfile -t saved < <(record_query overwritten_paths "$record" 2>/dev/null)
declare -A saved_before=()
for path in "${saved[@]}"; do
  saved_before[$path]=$(fingerprint "$path")
done
candidates=()
# Shown untracked files all count, wherever they are in the area: a repo whose
# git status lists many of them can ignore them to skip the backup.
# Under C.UTF-8, '.' doesn't match a byte that isn't valid UTF-8, which leaves
# such names out: init's are ASCII. Without that locale, grep falls back to C
# and keeps them.
read_top_paths candidates "$top" < <(
  {
    init_area_untracked --exclude-standard
    init_write_ignored
  } | LC_ALL=C.UTF-8 grep -z -a -x '.*'
)

# Drops the copies of candidates other than the paths given.
prune_originals() { # paths to keep...
  local path copy
  for path in "${!fp_before[@]}"; do
    in_list "$path" "$@" && continue
    copy=$originals/${path#"$top"/}
    # An interrupted put_copy leaves its .liza-tmp.
    rm -f -- "$copy" "$copy.liza-tmp"
  done
  find "$record_dir" -depth -type d -empty -delete 2>/dev/null
}

declare -A fp_before=()
left_over=()
for path in "${candidates[@]}"; do
  in_list "$path" "${recorded_files[@]}" "${saved[@]}" && continue
  fp=$(fingerprint "$path")
  [ -n "$fp" ] || continue
  copy=$originals/${path#"$top"/}
  # No record lists a copy already here (those paths are skipped above): an
  # interrupted activation left it. One that differs from its file may be the
  # user's only copy: backing the file up over it, or pruning it after init,
  # would lose it. Backing it up over one that matches loses nothing.
  if { [ -e "$copy" ] || [ -L "$copy" ]; } \
    && ! same_content "$copy" "$path"; then
    left_over+=("$copy")
    continue
  fi
  fp_before[$path]=$fp
done
# A held copy in clone-versions/ of a file init replaces without asking (below)
# may also be the user's only one: an interrupted activation or a failed merge
# write leaves it there.
clone_versions="$record_dir/clone-versions"
for name in "${merged_files[@]}"; do
  copy=$clone_versions/$name
  if { [ -e "$copy" ] || [ -L "$copy" ]; } \
    && ! same_content "$copy" "$top/$name"; then
    left_over+=("$copy")
  fi
done
if [ "${#left_over[@]}" -gt 0 ]; then
  printf -v list '%s, ' "${left_over[@]}"
  refuse "an interrupted or failed activation left copies that differ from" \
    "your files and may be your only ones: ${list%, }. Compare each with its" \
    "file, keep what you want, and move the copy out of its folder."
fi
# An interrupted backup drops its copies: init hasn't run, so none is needed.
trap 'prune_originals; unlock' EXIT
for path in "${!fp_before[@]}"; do
  copy=$originals/${path#"$top"/}
  # Without this copy, init could destroy the file for good: stop before it
  # runs.
  if ! { mkdir -p "$(dirname "$copy")" && put_copy "$path" "$copy"; }; then
    echo "liza shim: could not back up $path before init; nothing was" \
      "changed." >&2
    exit 1
  fi
done

# The fingerprints of the clone's versions held in clone-versions/ for the run
# below.
declare -A held_fp=()
drop_held() {
  rm -rf -- "$clone_versions"
}

# Puts the copy of the file at $1 back from the directory $2, and sets the
# caller's replaced when it set the file aside first.
restore_from() { # path copy-dir
  local rel=${1#"$top"/}
  if [ -e "$1" ] || [ -L "$1" ]; then
    if ! { mkdir -p "$(dirname "$record_dir/replaced/$rel")" \
      && cp -P -p "$1" "$record_dir/replaced/$rel"; }; then
      echo "liza shim: left $1 as the failed init left it; its original is" \
        "in $2." >&2
      return 1
    fi
    replaced=true
  fi
  put_copy "$2/$rel" "$1" && return 0
  echo "liza shim: could not restore $1 after the failed init; its original" \
    "is in $2." >&2
  return 1
}

# A failed or interrupted init is undone for the user's files too: each
# candidate it changed goes back from originals/, and each held file from
# clone-versions/. What it replaces could be init's write or the user's own
# edit made during init, which can't be told apart, so that is set aside in
# replaced/.
restore_after_failure() {
  local path name replaced=false kept=() keep_held=false
  for path in "${!fp_before[@]}"; do
    [ "$(fingerprint "$path")" = "${fp_before[$path]}" ] && continue
    restore_from "$path" "$originals" || kept+=("$path")
  done
  for name in "${!held_fp[@]}"; do
    path=$top/$name
    [ "$(fingerprint "$path")" = "${held_fp[$name]}" ] && continue
    restore_from "$path" "$clone_versions" || keep_held=true
  done
  $replaced && echo "liza shim: restored the files the failed init changed;" \
    "what it replaced is in $record_dir/replaced." >&2
  prune_originals "${kept[@]}"
  $keep_held || drop_held
}

# --- Swap the local settings in for init to merge into ---
# Liza always merges into .claude/settings.json. Putting the local file in its
# place for the run lets Liza's own merge write the local file, and the
# committed one is never opened.
restore_settings() {
  [ -f "$shared_settings" ] && mv -f "$shared_settings" "$local_settings"
  [ -f "$held_settings" ] && mv -f "$held_settings" "$shared_settings"
}
# Liza writes settings non-atomically and only warns when the merge fails, so
# the result is kept only if init succeeded and it parses and carries Liza's
# hooks; otherwise the backup, the one copy of the untracked local settings,
# goes back.
init_ok=true rc=1 released=false
# Runs once: a signal before the EXIT trap is swapped below would run it again.
release() {
  $released && return
  released=true
  restore_settings
  if [ "$rc" -ne 0 ] || ! jq -e '.hooks.SessionStart | length > 0' \
    "$local_settings" >/dev/null 2>&1; then
    init_ok=false
    if [ -f "$backup_settings" ]; then
      mv -f "$backup_settings" "$local_settings"
    else
      rm -f "$local_settings"
    fi
  fi
  rm -f "$backup_settings"
}
[ -f "$local_settings" ] && cp -p "$local_settings" "$backup_settings"
[ -f "$shared_settings" ] && mv "$shared_settings" "$held_settings"
[ -f "$local_settings" ] && mv "$local_settings" "$shared_settings"
trap 'release; restore_after_failure; unlock' EXIT

# --- Hold the clone's versions of the files init replaces without asking ---
# With --yes, init replaces these, and once Liza created one, the record lists
# it, so it isn't backed up above. A symlink or a directory there is left to
# init.
liza_versions="$record_dir/liza-versions"
merging=()
for name in "${merged_files[@]}"; do
  path=$top/$name
  if [ -L "$path" ] || { [ -e "$path" ] && [ ! -f "$path" ]; }; then
    continue
  fi
  merging+=("$name")
  [ -f "$path" ] || continue
  if ! { mkdir -p "$clone_versions" \
    && cp -p "$path" "$clone_versions/$name"; }; then
    echo "liza shim: could not hold $path before init; nothing was" \
      "changed." >&2
    exit 1
  fi
  held_fp[$name]=$(fingerprint "$path")
done

# --- Run Liza's init ---
"$real_liza" "$@"
rc=$?
# The refusal code is the shim's own: init failing with it is still a failure.
[ "$rc" -eq "$liza_refused" ] && rc=1

release
trap unlock EXIT
if [ "$rc" -ne 0 ]; then
  restore_after_failure
  exit "$rc"
fi
if ! $init_ok; then
  restore_after_failure
  echo "liza shim: init left no valid Liza hooks in settings.local.json;" \
    "restored it and linked nothing." >&2
  exit 1
fi

# --- Merge the clone's edits into the files init replaced ---
# Puts the clone's version of the file at $1, held in $2, back after init,
# merged with what Liza changed since its output in $3. Without that base, or
# on a conflict, it goes back as it was, with Liza's output beside it. Leaves
# Liza's output in $2.liza.
keep_clone_version() { # path held base
  local merged=$2.merged
  if ! cp -p "$1" "$2.liza"; then
    echo "liza shim: could not merge your $1 after init; it is in $2." >&2
    return 1
  fi
  # cp -p gives the result the clone's file mode; the merge then replaces its
  # content.
  if [ -f "$3" ] && cp -p "$2" "$merged" \
    && git merge-file -q -p "$2" "$3" "$2.liza" >"$merged" \
    && put_copy "$merged" "$1"; then
    return 0
  fi
  rm -f -- "$merged"
  if ! { put_copy "$2.liza" "$1.liza" && put_copy "$2" "$1"; }; then
    echo "liza shim: could not put your $1 back after init; it is in $2." >&2
    return 1
  fi
  echo "liza shim: kept your $1 over Liza's version, which is in $1.liza;" \
    "merge what you need from it." >&2
}

# Succeeds when the clone's held version of the file named $1 is Liza's output
# from the last activation, which stored no base: an earlier Feature version
# stored none, but its record has the fingerprint of Liza's output, under
# overwritten for a file of the clone's own from before Liza.
liza_wrote_held() { # name
  { [ ! -f "$liza_versions/$1" ] && [ -f "$record" ]; } || return 1
  # shellcheck disable=SC2016 # a jq program
  [ "$(record_jq '(.files + (.overwritten // []))[] | select(.path == $p)
    | .fp' -r --arg p "$top/$1" "$record" 2>/dev/null)" \
    = "${held_fp[$1]##* }" ]
}

# Wherever init wrote the file, Liza's output becomes the next merge base, so a
# conflict is reported once. A file init left alone keeps its base: Liza may
# not have written it, and the clone's file as a base would later merge Liza's
# template over the clone's content.
keep_held=false
declare -A liza_fp=()
for name in "${merging[@]}"; do
  path=$top/$name held=$clone_versions/$name liza_output=$path
  if [ -L "$path" ] || [ ! -f "$path" ]; then
    # Init removed the file or put something else there: the held copy is the
    # clone's only one.
    [ -f "$held" ] || continue
    if ! put_copy "$held" "$path"; then
      echo "liza shim: could not put your $path back after init; it is in" \
        "$held." >&2
      keep_held=true
    fi
    continue
  fi
  if [ -f "$held" ] && ! liza_wrote_held "$name"; then
    cmp -s "$held" "$path" && continue
    # Liza's version left beside the file at an earlier conflict, unedited, is
    # outdated once init writes another: the merge below starts from it.
    cmp -s "$path.liza" "$liza_versions/$name" \
      && ! cmp -s "$path.liza" "$path" && rm -f -- "$path.liza"
    if ! keep_clone_version "$path" "$held" "$liza_versions/$name"; then
      keep_held=true
      continue
    fi
    liza_output=$held.liza
    fp=$(fingerprint "$liza_output")
    liza_fp[$path]=${fp##* }
  fi
  { mkdir -p "$liza_versions" \
    && put_copy "$liza_output" "$liza_versions/$name"; } \
    || echo "liza shim: could not keep Liza's $name to merge with next" \
      "time." >&2
done
$keep_held || drop_held

# Prints a fingerprint entry, with Liza's output's fingerprint for a file merged
# above: deactivation then counts the clone's edits in it as made since
# activation, and keeps the file.
as_liza_wrote() { # entry
  local path=${1% *}
  printf '%s %s\n' "$path" "${liza_fp[$path]:-${1##* }}"
}

# --- Finish activation locally ---
# rtk's own `rtk init -g` writes this hook to
# ~/.claude/settings.json, rewriting commands in every project; here it applies
# to activated clones only.
rtk="$HOME/.liza/bin/rtk"
if [ -d "$liza_toolchain" ] && [ -x "$rtk" ] && [ -f "$local_settings" ]; then
  if ! { jq --arg cmd "$rtk hook claude" '
        .hooks.PreToolUse //= []
        | if any(.hooks.PreToolUse[].hooks[]?; .command == $cmd) then .
          else .hooks.PreToolUse += [{matcher: "Bash",
            hooks: [{type: "command", command: $cmd}]}] end
    ' "$local_settings" >"$local_settings.tmp" \
    && mv "$local_settings.tmp" "$local_settings"; }; then
    rm -f "$local_settings.tmp"
    echo "liza shim: could not add rtk's hook to $local_settings" >&2
  fi
fi

# `--claude` points ~/.claude/CLAUDE.md at the contract when that path is free,
# which loads the contract in every project sharing ~/.claude. Keep it in this
# clone instead.
if ! $had_global_contract \
  && [ "$(readlink "$global_contract")" = "$liza_contract" ]; then
  rm -- "$global_contract"
fi
# A symlink, not an @import: imports outside the project are skipped in `claude
# -p` sessions, and a worktree session skips an ancestor CLAUDE.local.md's
# imports.
contract="$top/CLAUDE.local.md"
if [ -L "$contract" ] || [ ! -e "$contract" ]; then
  ln -sfn "$liza_contract" "$contract"
else
  echo "Warning: $contract is your own file, so Liza's contract was not" \
    "linked there." >&2
fi

for skill_md in "$HOME"/.liza/skills/*/SKILL.md; do
  [ -e "$skill_md" ] || continue
  skill_dir=${skill_md%/SKILL.md}
  link="$claude_dir/skills/${skill_dir##*/}"
  if [ -L "$link" ] || [ ! -e "$link" ]; then
    mkdir -p "$claude_dir/skills"
    ln -sfn "$skill_dir" "$link"
  fi
done

# Whatever init just created that git would show (hooks, .claudeignore, skill
# links) is this clone's activation, not project content: exclude it locally.
declare -A was_untracked=() shown=()
for path in "${untracked_before[@]}"; do was_untracked[$path]=1; done
shown_after=() hidden_after=()
read_top_paths shown_after "$top" < <(shown_untracked)
read_top_paths hidden_after "$top" < <(hidden_untracked)
for path in "${shown_after[@]}"; do shown[$path]=1; done
created=()
for path in "${shown_after[@]}" "${hidden_after[@]}"; do
  [ -n "${was_untracked[$path]+set}" ] || created+=("$path")
done
# A line appended to a file without a final newline would join its last line.
mkdir -p "$(dirname "$exclude_file")"
[ -s "$exclude_file" ] && [ -n "$(tail -c 1 "$exclude_file")" ] \
  && echo >>"$exclude_file"
for path in "${created[@]}"; do
  [ -n "${shown[$path]+set}" ] && exclude_line "${path#"$top"/}"
done >>"$exclude_file"

# --- Record what this activation changed, so deactivate.sh undoes exactly
# that ---
# Candidates init changed keep their copy in originals/ and are recorded as
# overwritten, with the fingerprint of Liza's version ("absent" if init removed
# the file).
overwritten=() keep=("${saved[@]}")
for path in "${!fp_before[@]}"; do
  now=$(fingerprint "$path")
  now=${now:-"$path absent"}
  [ "$now" != "${fp_before[$path]}" ] || continue
  overwritten+=("$(as_liza_wrote "$now")") keep+=("$path")
done
# A file an earlier activation overwrote keeps that first original; one this
# init rewrote again takes the new fingerprint, so deactivate still restores it.
for path in "${saved[@]}"; do
  now=$(fingerprint "$path")
  [ "$now" != "${saved_before[$path]}" ] \
    && overwritten+=("$(as_liza_wrote "${now:-"$path absent"}")")
done
prune_originals "${keep[@]}"

# Liza's own exclude lines cover files its tools generate, which deactivate.sh
# removes; one that existed before init is the user's, and is left.
exclude_added=$(comm -13 <(sort -u <<<"$exclude_before") \
  <(sort -u "$exclude_file"))
preexisting=()
while IFS= read -r line; do
  # Only in the area the shim lists: deactivate.sh names a file elsewhere as
  # one the shim couldn't see.
  [ -n "$line" ] && rel=$(exclude_line_path "$line") \
    && [[ "$rel" != */* || "$rel" == .claude/* ]] \
    && [ -n "${was_untracked["$top/$rel"]+set}" ] \
    && preexisting+=("$top/$rel")
done <<<"$exclude_added"

# Each fingerprint list is "<path> <fingerprint>" lines, taken before and after
# init: files already recorded (a later init may rewrite them), new worktree
# files, and the git dir's hooks and liza* files. activation-record.jq folds
# them into the record.
mkdir -p "$record_dir"
[ -f "$record" ] \
  || record_jq empty_record -n >"$record"
# shellcheck disable=SC2016 # a jq program
if ! { record_jq 'record_activation($pre[0]; $post[0]; $created;
  $recorded_before; $recorded_after; $git_before; $git_after; $overwritten;
  $exclude_added; $preexisting)' \
  --slurpfile pre <(printf '%s' "$pre_settings") \
  --slurpfile post "$local_settings" \
  --arg created "$(fingerprint "${created[@]}")" \
  --arg recorded_before "$recorded_before" \
  --arg recorded_after "$(fingerprint "${recorded_files[@]}" \
    | while IFS= read -r entry; do as_liza_wrote "$entry"; done)" \
  --arg git_before "$git_before" \
  --arg git_after "$(fingerprint "$git_dir"/liza* "$hooks_dir"/*)" \
  --arg overwritten "$(printf '%s\n' "${overwritten[@]}")" \
  --arg exclude_added "$exclude_added" \
  --arg preexisting "$(printf '%s\n' "${preexisting[@]}")" \
  "$record" >"$record.tmp" && mv "$record.tmp" "$record"; }; then
  rm -f "$record.tmp"
  echo "liza shim: could not record this activation; liza-deactivate will" \
    "only partly undo it. Originals of files init overwrote are in" \
    "$originals; liza-activate refuses until the copies of files init" \
    "rewrote are moved out of it." >&2
  exit 1
fi
