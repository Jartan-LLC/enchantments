#!/bin/bash
# onCreateCommand, as the remote user: link ~/.config/gh to the gh-config
# volume, and say so when gh isn't logged in.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
# shellcheck source=fix_volume_owner.sh
. "$here/fix_volume_owner.sh"
# shellcheck source=link_home.sh
. "$here/link_home.sh"
id=gh-config
mount=/mnt/enchantments/gh-config

fix_volume_owner "$mount" \
  || record_failure "$id" "can't take ownership of $mount without" \
    "passwordless sudo; run: sudo chown -R $(id -un) $mount"
if ! link_home "$HOME/.config/gh" "$mount"; then
  record_failure "$id" "$HOME/.config/gh is in the way of gh-config, so gh's" \
    "login won't persist; move it aside, then run: bash $here/onCreate.sh"
elif command -v gh >/dev/null && ! gh auth token >/dev/null 2>&1; then
  record_failure "$id" "gh isn't logged in: run 'gh auth login'; the login" \
    "then survives rebuilds"
fi
