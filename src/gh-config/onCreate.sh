#!/bin/bash
# onCreateCommand, as the remote user: link ~/.config/gh to the gh-config
# volume.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
# shellcheck source=volume_owner.sh
. "$here/volume_owner.sh"
# shellcheck source=link_home.sh
. "$here/link_home.sh"
id=gh-config
mount=/mnt/enchantments/gh-config

problem=$(fix_volume_owner "$mount" "gh may fail to save its login") \
  || record_failure "$id" "$problem"
if ! link_home "$HOME/.config/gh" "$mount"; then
  record_failure "$id" "$HOME/.config/gh is in the way of gh-config, so gh's" \
    "login won't persist; move it aside, then run: bash $here/onCreate.sh"
fi
