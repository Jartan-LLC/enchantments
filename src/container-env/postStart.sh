#!/bin/bash
# postStartCommand, as the remote user: report the volume's problems and
# overrides, at every start while they last, then what the create-time hooks
# recorded.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
# shellcheck source=pending_failures.sh
. "$here/pending_failures.sh"
# shellcheck source=fix_volume_owner.sh
. "$here/fix_volume_owner.sh"
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
if ! pending_failures "$id" && ! owns_volume "$mount"; then
  record_failure "$id" "$mount holds files you don't own, so you may not be" \
    "able to change its variables; run: sudo chown -R $(id -un) $mount"
fi
report_failures "$id"
