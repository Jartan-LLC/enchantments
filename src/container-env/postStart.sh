#!/bin/bash
# postStartCommand, as the remote user: take back files a root container left
# in the volume, and report its problems and overrides, at every start while
# they last, then report what the hooks recorded.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
# shellcheck source=start_checks.sh
. "$here/start_checks.sh"
# shellcheck source=volume_checks.sh
. "$here/volume_checks.sh"
id=container-env
mount=/mnt/enchantments/container-env

# A root container sharing the volume leaves files this user can't change,
# or read where they're 0600: take them back before checking the values.
if ! pending_failures "$id"; then
  take_back_root_files "$id" "$mount" "you may fail to change its variables"
fi
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
