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
core_contract=$liza_contract

# Refuses this init with exit 75, which init itself never passes on, so a
# caller can tell a refusal from a failure. The message also goes to the file
# $LIZA_SHIM_REFUSAL names, when set, for a caller that records it.
refuse() { # message...
  echo "liza shim: $*" >&2
  [ -z "${LIZA_SHIM_REFUSAL:-}" ] || printf '%s\n' "$*" >"$LIZA_SHIM_REFUSAL"
  exit 75
}

# Takes a lock directory; refuses when another holder has it.
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
take_lock "$lock" "another init" && have_lock=true
take_lock "$repo_lock" "another worktree's init" && have_repo_lock=true
# A repo's worktrees share its git hooks and exclude file.
active=$(other_activation "$top")
case $? in
  0) refuse "Liza is active in $active, another worktree of this repo; run" \
    "liza-deactivate there first." ;;
  2) refuse "git can't list this repo's worktrees, so another one's" \
    "activation can't be ruled out; Liza needs git 2.36 or later." ;;
esac
if [ -e "$held_settings" ]; then
  refuse "$held_settings exists from an interrupted init; move it back to" \
    "settings.json (and any settings.local.json.liza-shim-backup back to" \
    "settings.local.json) first."
fi

# --- Snapshot the state before init ---
had_global_contract=false
if [ -e "$global_contract" ] || [ -L "$global_contract" ]; then
  had_global_contract=true
fi
# Untracked paths at the top level and in .claude/, where init writes, minus
# the two settings files activation manages itself.
init_area_untracked() { # ls-files-options...
  git -C "$top" ls-files -z --others "$@" -- .claude ':(glob)*' \
    | grep -z -v -x -F -e .claude/settings.local.json -e .claude/settings.json
}
# A file init creates counts as its own whether git shows it or an exclude line
# hides it.
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
# Liza's init overwrites or removes an untracked file of the user's at a path
# it writes to. Each such candidate (file or symlink) is copied to originals/
# first, and the copy stays only if init changes the file. Liza's own files
# are skipped, and so is a file an earlier activation already saved: that
# first copy is the user's.
originals="$record_dir/originals"
mapfile -t saved < <(record_query overwritten_paths "$record" 2>/dev/null)
declare -A saved_before=()
for path in "${saved[@]}"; do
  saved_before[$path]=$(fingerprint "$path")
done
candidates=()
read_top_paths candidates "$top" < <(init_area_untracked)

# Drops the copies of candidates other than the paths given.
prune_originals() { # paths to keep...
  local path
  for path in "${!fp_before[@]}"; do
    printf '%s\n' "$@" | grep -q -x -F -- "$path" \
      || rm -f -- "$originals/${path#"$top"/}"
  done
  find "$record_dir" -depth -type d -empty -delete 2>/dev/null
}

declare -A fp_before=()
for path in "${candidates[@]}"; do
  printf '%s\n' "${recorded_files[@]}" "${saved[@]}" \
    | grep -q -x -F -- "$path" && continue
  fp=$(fingerprint "$path")
  [ -n "$fp" ] || continue
  fp_before[$path]=$fp
  # Without this copy, init could destroy the file for good: stop before it
  # runs.
  copy=$originals/${path#"$top"/}
  if ! { mkdir -p "$(dirname "$copy")" && cp -P -p "$path" "$copy"; }; then
    prune_originals
    echo "liza shim: could not back up $path before init; nothing was" \
      "changed." >&2
    exit 1
  fi
done

# A failed or interrupted init is undone for the user's files too: each
# candidate it changed goes back from originals/. What it replaces could be
# init's write or the user's own edit made during init, which can't be told
# apart, so that is set aside in replaced/.
restore_candidates() {
  local path rel replaced=false kept=()
  for path in "${!fp_before[@]}"; do
    [ "$(fingerprint "$path")" = "${fp_before[$path]}" ] && continue
    rel=${path#"$top"/}
    if [ -e "$path" ] || [ -L "$path" ]; then
      if ! { mkdir -p "$(dirname "$record_dir/replaced/$rel")" \
        && cp -P -p "$path" "$record_dir/replaced/$rel"; }; then
        kept+=("$path")
        echo "liza shim: left $path as the failed init left it; its original" \
          "is in $originals." >&2
        continue
      fi
      replaced=true
    fi
    put_copy "$originals/$rel" "$path" && continue
    kept+=("$path")
    echo "liza shim: could not restore $path after the failed init; its" \
      "original is in $originals." >&2
  done
  $replaced && echo "liza shim: restored the files the failed init changed;" \
    "what it replaced is in $record_dir/replaced." >&2
  prune_originals "${kept[@]}"
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
trap 'release; restore_candidates; unlock' EXIT

# --- Run Liza's init ---
# Liza reads the toolchain's LIZA_ENABLE_* gates at init
# time, and the shell running init (a script, /onboard, Liza's operator agent)
# may not have loaded them.
toolchain=/usr/local/share/enchantments/liza-toolchain
if [ -d "$toolchain" ] && [ -f "$HOME/.liza/toolchain/env.sh" ]; then
  # shellcheck source=/dev/null
  source "$HOME/.liza/toolchain/env.sh"
fi

"$real_liza" "$@"
rc=$?
[ "$rc" -eq 75 ] && rc=1 # 75 means refused

release
trap unlock EXIT
if [ "$rc" -ne 0 ]; then
  restore_candidates
  exit "$rc"
fi
if ! $init_ok; then
  restore_candidates
  echo "liza shim: init left no valid Liza hooks in settings.local.json;" \
    "restored it and linked nothing." >&2
  exit 1
fi

# --- Finish activation locally ---
# rtk's own `rtk init -g` writes this hook to
# ~/.claude/settings.json, rewriting commands in every project; here it applies
# to activated clones only.
rtk="$HOME/.liza/bin/rtk"
if [ -d "$toolchain" ] && [ -x "$rtk" ] && [ -f "$local_settings" ]; then
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
  && [ "$(readlink "$global_contract")" = "$core_contract" ]; then
  rm -- "$global_contract"
fi
# A symlink, not an @import: imports outside the project are skipped in `claude
# -p` sessions, and a worktree session skips an ancestor CLAUDE.local.md's
# imports.
contract="$top/CLAUDE.local.md"
if [ -L "$contract" ] || [ ! -e "$contract" ]; then
  ln -sfn "$core_contract" "$contract"
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
  overwritten+=("$now") keep+=("$path")
done
# A file an earlier activation overwrote keeps that first original; one this
# init rewrote again takes the new fingerprint, so deactivate still restores it.
for path in "${saved[@]}"; do
  now=$(fingerprint "$path")
  [ "$now" != "${saved_before[$path]}" ] \
    && overwritten+=("${now:-"$path absent"}")
done
prune_originals "${keep[@]}"

# Liza's own exclude lines cover files its tools generate, which deactivate.sh
# removes; one that existed before init is the user's, and is left.
exclude_added=$(comm -13 <(sort -u <<<"$exclude_before") \
  <(sort -u "$exclude_file"))
preexisting=()
while IFS= read -r line; do
  [ -n "$line" ] && rel=$(exclude_line_path "$line") \
    && [ -n "${fp_before["$top/$rel"]+set}" ] \
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
  --arg recorded_after "$(fingerprint "${recorded_files[@]}")" \
  --arg git_before "$git_before" \
  --arg git_after "$(fingerprint "$git_dir"/liza* "$hooks_dir"/*)" \
  --arg overwritten "$(printf '%s\n' "${overwritten[@]}")" \
  --arg exclude_added "$exclude_added" \
  --arg preexisting "$(printf '%s\n' "${preexisting[@]}")" \
  "$record" >"$record.tmp" && mv "$record.tmp" "$record"; }; then
  rm -f "$record.tmp"
  echo "liza shim: could not record this activation; liza-deactivate will" \
    "only partly undo it. Originals of files init overwrote are in" \
    "$originals." >&2
  exit 1
fi
