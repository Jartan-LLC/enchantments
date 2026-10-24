#!/bin/bash
# postStartCommand, as the remote user: check what onCreate set up, note a gh
# that isn't logged in, then report what the hooks recorded. A missing login
# is a note, not a failure: a container in CI has none.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
# shellcheck source=start_checks.sh
. "$here/start_checks.sh"
# shellcheck source=volume_owner.sh
. "$here/volume_owner.sh"
# shellcheck source=volume_checks.sh
. "$here/volume_checks.sh"
id=gh-config
mount=/mnt/enchantments/gh-config
linked=false
[ "$HOME/.config/gh" -ef "$mount" ] && linked=true

# A later step can replace the link, a root container sharing the volume
# leaves files this user can't change, and another user's container leaves
# files this user mustn't take.
if ! pending_failures "$id"; then
  "$linked" \
    || record_at_start "$id" "$HOME/.config/gh isn't linked to gh-config, so" \
      "gh's login won't persist;" \
      "$(relink_advice "$HOME/.config/gh" "$here/onCreate.sh")"
  problem=$(take_back_volume "$mount" "gh may fail to save its login") \
    || record_at_start "$id" "$problem"
fi
if "$linked" && command -v gh >/dev/null \
  && ! gh auth token >/dev/null 2>&1; then
  echo "$id: gh isn't logged in: run 'gh auth login'; the login then" \
    "survives rebuilds" >&2
fi
report_failures "$id"
