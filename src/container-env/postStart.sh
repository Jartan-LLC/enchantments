#!/bin/bash
# postStartCommand, as the remote user: report problems with the volume's
# files and the overrides between them, which recur until they're fixed,
# then what the create-time hooks recorded.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
id=container-env

while read -r kind text; do
  case $kind in
    problem) echo "Warning: $id: $text" >&2 ;;
    note) echo "$id: $text" >&2 ;;
  esac
done < <(bash "$here/load.sh" --check)
report_failures "$id"
