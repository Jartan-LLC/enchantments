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
# shellcheck source=fix_volume_owner.sh
. "$here/fix_volume_owner.sh"
id=gh-config
mount=/mnt/enchantments/gh-config
linked=false
[ "$HOME/.config/gh" -ef "$mount" ] && linked=true

# A later step can replace the link, and a root container sharing the volume
# leaves files this user can't change until they're taken back.
if ! pending_failures "$id"; then
  "$linked" \
    || record_at_start "$id" "$HOME/.config/gh isn't linked to gh-config, so" \
      "gh's login won't persist; move it aside, then run: bash" \
      "$here/onCreate.sh"
  fix_volume_owner "$mount" \
    || record_at_start "$id" "can't take back the files in $mount you don't" \
      "own without passwordless sudo, so gh may fail to save its login; run:" \
      "sudo chown -R $(id -un) $mount"
fi
if "$linked" && command -v gh >/dev/null \
  && ! gh auth token >/dev/null 2>&1; then
  echo "$id: gh isn't logged in: run 'gh auth login'; the login then" \
    "survives rebuilds" >&2
fi
report_failures "$id"
