#!/bin/bash
# onCreateCommand, as the remote user: take ownership of the container-env
# volume, so the user can write its files.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
# shellcheck source=volume_owner.sh
. "$here/volume_owner.sh"
id=container-env
mount=/mnt/enchantments/container-env

problem=$(fix_volume_owner "$mount" "you may fail to change its variables") \
  || record_failure "$id" "$problem"
