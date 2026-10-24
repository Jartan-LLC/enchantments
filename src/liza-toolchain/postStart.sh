#!/bin/bash
# postStartCommand, as the remote user: check that each tool onCreate installed
# is still in the volume, then report what the hooks recorded.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
# shellcheck source=start_checks.sh
. "$here/start_checks.sh"
# shellcheck source=tools.sh
. "$here/tools.sh" # mount, npm_tools, retry
id=liza-toolchain

# A pin tools.sh doesn't list is a tool a later release dropped, so it's left
# alone.
if ! pending_failures "$id" && [ -d "$mount/bin/.pins" ]; then
  missing=()
  for pin in "$mount"/bin/.pins/*; do
    [ -e "$pin" ] || continue
    while read -r file; do
      [ -z "$file" ] || missing+=("${file##*/}")
    done <<<"$(missing_files "${pin##*/}")"
  done
  [ "${#missing[@]}" -eq 0 ] \
    || record_at_start "$id" "missing from the toolchain, or not executable:" \
      "${missing[*]}; $retry"
fi
report_failures "$id"
