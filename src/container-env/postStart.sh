#!/bin/bash
# postStartCommand, as the remote user: report the volume's problems and
# overrides, at every start while they last, then what the create-time hooks
# recorded.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
id=container-env

if ! report=$(bash "$here/load.sh" --check); then
  echo "Warning: $id: the loader failed; run: bash $here/load.sh --check" >&2
fi
while read -r kind text; do
  case $kind in
    problem) echo "Warning: $id: $text" >&2 ;;
    note) echo "$id: $text" >&2 ;;
  esac
done <<<"$report"
report_failures "$id"
