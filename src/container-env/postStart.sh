#!/bin/bash
# postStartCommand, as the remote user: take back files a root container left
# in the volume, warn of another user's, report the Feature's problems and
# overrides at every start while they last, then report what the hooks
# recorded.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
# shellcheck source=start_checks.sh
. "$here/start_checks.sh"
# shellcheck source=volume_owner.sh
. "$here/volume_owner.sh"
id=container-env
mount=/mnt/enchantments/container-env

# A root container sharing the volume leaves files this user can't change,
# or read where they're 0600: take them back before checking the values.
# Another user's stay theirs, and root's wait while they're there.
if ! pending_failures "$id"; then
  problem=$(take_back_volume "$mount" "you may fail to change its variables") \
    || record_at_start "$id" "$problem"
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
