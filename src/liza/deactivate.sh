#!/bin/bash
# liza-deactivate: undoes activation in this clone, from the record the shim
# keeps: the settings entries and files activation added (a file edited since is
# kept and named), its exclude lines and the contract link. --tools instead
# removes the context7 registration activation made with the toolchain. ~/.liza
# stays: it's this project's volume.
# shellcheck source-path=SCRIPTDIR

set -uo pipefail

here=$(dirname "$(readlink -f "$0")")
top=$(git rev-parse --show-toplevel) || exit 1
cd "$top" || exit 1
# shellcheck source=activation-lib.sh
source "$here/activation-lib.sh"
# shellcheck source=activation-steps.sh
source "$here/activation-steps.sh"
failed=()

finish() {
  if [ ${#failed[@]} -gt 0 ]; then
    echo "Warning: Liza deactivation failed: ${failed[*]}" >&2
    exit 1
  fi
  exit 0
}

# Remove a file activation created, unless the project has since started
# tracking it. A failed removal is recorded, so the record survives for a rerun.
remove_created() {
  git ls-files --error-unmatch -- "$1" >/dev/null 2>&1 && return 0
  rm -f -- "$1" || {
    failed+=("removing $1")
    return 1
  }
}

if [ "${1:-}" = --tools ]; then
  remove_context7
  exit
fi

# --- Undo activation, from its record ---
local_settings=$top/.claude/settings.local.json
record_dir=$(record_dir_of "$top")
record="$record_dir/activation.json"
exclude_file=$(git_path "$top" info/exclude)

# Nothing to undo. Originals alone are an activation interrupted before its
# record or link was made, and are undone; so is a contract link alone.
activated "$top" || contract_linked "$top" || finish

lock=.claude/.liza-shim.lock
if ! mkdir -p .claude || ! mkdir "$lock" 2>/dev/null; then
  echo "deactivate: $lock is held by a running liza init; remove it with" \
    "rmdir if none is running." >&2
  exit 1
fi
trap 'rmdir "$lock"' EXIT

drop_lines=()     # exclude lines to remove
recorded_paths=() # the files activation created
kept=()           # what is left for the user to check
accounted=()      # originals the record lists
if ! jq -e . "$record" >/dev/null 2>&1; then
  # No readable record: only the contract link and any saved originals can be
  # undone.
  echo "deactivate: no readable activation record, so Liza's settings" \
    "entries and files were left; check $local_settings and" \
    "$exclude_file." >&2
else
  # Liza's settings entries go; entries the user added or changed since stay.
  if [ -f "$local_settings" ]; then
    # shellcheck disable=SC2016 # a jq program
    if ! { record_jq 'revert($rec[0].settings)' --slurpfile rec "$record" \
      "$local_settings" >"$local_settings.tmp" \
      && mv "$local_settings.tmp" "$local_settings"; }; then
      rm -f "$local_settings.tmp"
      failed+=("settings revert")
    fi
  fi
  # A user file init overwrote or removed gets its original back, unless Liza's
  # version was edited since; then the original goes beside it.
  mapfile -t overwritten < <(record_query overwritten_entries "$record")
  for entry in "${overwritten[@]}"; do
    path=${entry% *}
    original="$record_dir/originals/${path#"$top"/}"
    [ -e "$original" ] || [ -L "$original" ] || continue
    accounted+=("$original")
    now=$(fingerprint "$path")
    restored=$(fingerprint "$original")
    # Already restored by an earlier, failed run: the two fingerprints (minus
    # their differing paths) match.
    [ -n "$now" ] && [ "${now#"$path" }" = "${restored#"$original" }" ] \
      && continue
    if [ "${now:-"$path absent"}" = "$entry" ]; then
      put_copy "$original" "$path" || failed+=("restoring $path")
    else
      if cp -P -p "$original" "$path.pre-liza"; then
        kept+=("$path (original in $path.pre-liza)")
      else
        failed+=("saving $path.pre-liza")
      fi
    fi
  done
  # A file activation created goes, unless it was edited since.
  mapfile -t recorded < <(record_query file_entries "$record")
  mapfile -t recorded_paths < <(record_query recorded_paths "$record")
  for entry in "${recorded[@]}"; do
    path=${entry% *}
    # The settings revert above owns the local settings.
    [ "$path" = "$local_settings" ] && continue
    now=$(fingerprint "$path")
    [ -n "$now" ] || continue
    if [ "$now" = "$entry" ]; then
      remove_created "$path"
    else
      kept+=("$path")
    fi
  done
  # Liza's own exclude lines name files its tools generate after activation,
  # which go, edits included; one that existed before activation stays.
  mapfile -t drop_lines < <(record_query added_exclude_lines "$record")
  mapfile -t preexisting < <(record_query preexisting_paths "$record")
  for line in "${drop_lines[@]}"; do
    rel=$(exclude_line_path "$line") || continue
    path="$top/$rel"
    in_list "$path" "${recorded_paths[@]}" && continue
    in_list "$path" "${preexisting[@]}" && continue
    # The shim only saw the top level and .claude/ before init: elsewhere, the
    # file may be the user's.
    if [[ "$rel" == */* && "$rel" != .claude/* ]]; then
      { [ -f "$path" ] || [ -L "$path" ]; } && kept+=("$path")
      continue
    fi
    { [ -f "$path" ] || [ -L "$path" ]; } && remove_created "$path"
  done
fi

# An original the record doesn't list (the record's write failed after it was
# saved) is the user's only copy of that file: put it beside the file rather
# than drop it.
if [ -d "$record_dir/originals" ]; then
  while IFS= read -r -d '' original; do
    in_list "$original" "${accounted[@]}" && continue
    path="$top/${original#"$record_dir/originals/"}"
    if [ -e "$path.pre-liza" ] || [ -L "$path.pre-liza" ] \
      || { mkdir -p "$(dirname "$path")" \
        && cp -P -p "$original" "$path.pre-liza"; }; then
      kept+=("$path (original in $path.pre-liza)")
    else
      failed+=("saving $path.pre-liza")
    fi
  done < <(find "$record_dir/originals" \( -type f -o -type l \) -print0)
fi

# --- Clean up: the contract link, emptied settings and dirs, then what is
# left for the user ---
if [ -f "$local_settings" ] \
  && [ "$(jq -c . "$local_settings" 2>/dev/null)" = "{}" ]; then
  rm -f "$local_settings"
fi
contract_linked "$top" && remove_created CLAUDE.local.md
rmdir .claude/hooks .claude/skills 2>/dev/null

# After a failure the exclude lines stay too, so what's left stays hidden until
# a rerun.
if [ ${#failed[@]} -eq 0 ] && [ -f "$exclude_file" ] \
  && [ ${#drop_lines[@]} -gt 0 ]; then
  # grep exits 1 when no line is left, and 2 when it couldn't read the file.
  grep -v -x -F -f <(printf '%s\n' "${drop_lines[@]}") "$exclude_file" \
    >"$exclude_file.tmp"
  if [ $? -le 1 ] && mv "$exclude_file.tmp" "$exclude_file"; then
    :
  else
    rm -f "$exclude_file.tmp"
    failed+=("exclude cleanup")
  fi
fi
# Only a complete undo drops the record and the originals; after a failure they
# stay, and a rerun picks up where this one stopped.
if [ ${#failed[@]} -eq 0 ]; then
  rm -f -- "$record" "$record.tmp"
  rm -rf -- "${record_dir:?}/originals"
  rmdir "$record_dir" 2>/dev/null
fi
# Local settings activation created that still hold your own entries stay; once
# their exclude line is gone, git shows them, unless the repo ignores them.
if [ -f "$local_settings" ] \
  && in_list "$local_settings" "${recorded_paths[@]}" \
  && ! git check-ignore -q -- "$local_settings"; then
  kept+=("$local_settings (your own settings, which git now shows)")
fi
[ ${#kept[@]} -eq 0 ] \
  || echo "deactivate: left these for you to check: ${kept[*]}" >&2
finish
