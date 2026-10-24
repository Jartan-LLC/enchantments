#!/bin/bash
# postStartCommand, as the remote user: check that each tool onCreate installed
# is still in the volume, then report what the hooks recorded.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
# shellcheck source=pending_failures.sh
. "$here/pending_failures.sh"
# shellcheck source=tools.sh
. "$here/tools.sh"
id=liza-toolchain

if ! pending_failures "$id" && [ -d "$toolchain/bin/.pins" ]; then
  missing=()
  for pin in "$toolchain"/bin/.pins/*; do
    [ -e "$pin" ] || continue
    tool_installed "${pin##*/}" || missing+=("${pin##*/}")
  done
  [ "${#missing[@]}" -eq 0 ] \
    || record_failure "$id" "missing from the toolchain: ${missing[*]};" \
      "retry: bash $here/onCreate.sh"
fi
report_failures "$id"
