#!/bin/bash
# onCreateCommand, as the remote user: take ownership of the container-env
# volume, so the user can write its files.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
# shellcheck source=fix_volume_owner.sh
. "$here/fix_volume_owner.sh"
id=container-env
mount=/mnt/enchantments/container-env

fix_volume_owner "$mount" \
  || record_failure "$id" "can't take ownership of $mount without" \
    "passwordless sudo; run: sudo chown -R $(id -un) $mount"
