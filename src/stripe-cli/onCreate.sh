#!/bin/bash
# onCreateCommand, as the remote user: link ~/.config/stripe to the
# stripe-config volume, so stripe's login survives rebuilds.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
# shellcheck source=fix_volume_owner.sh
. "$here/fix_volume_owner.sh"
# shellcheck source=link_home.sh
. "$here/link_home.sh"
id=stripe-cli
mount=/mnt/enchantments/stripe-config

fix_volume_owner "$mount" \
  || record_failure "$id" "can't take ownership of $mount without" \
    "passwordless sudo; run: sudo chown -R $(id -un) $mount"
link_home "$HOME/.config/stripe" "$mount" \
  || record_failure "$id" "$HOME/.config/stripe is in the way of" \
    "stripe-config, so stripe's login won't persist; move it aside, then" \
    "run: bash $here/onCreate.sh"
