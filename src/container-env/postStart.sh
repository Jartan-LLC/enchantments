#!/bin/bash
# postStartCommand, as the remote user: report the volume's problems and
# overrides, and take back files a root container left in it, at every start
# while they last, then report what the hooks recorded.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
# shellcheck source=start_checks.sh
. "$here/start_checks.sh"
id=container-env
mount=/mnt/enchantments/container-env

if ! report=$(bash "$here/load.sh" --check); then
  echo "Warning: $id: the loader failed; run: bash $here/load.sh --check" >&2
fi
while read -r kind text; do
  case $kind in
    problem) echo "Warning: $id: $text" >&2 ;;
    note) echo "$id: $text" >&2 ;;
  esac
done <<<"$report"
# A root container sharing the volume leaves files this user can't change.
if ! pending_failures "$id"; then
  take_back_root_files "$id" "$mount" "you may fail to change its variables"
fi
report_failures "$id"
