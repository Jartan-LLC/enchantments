#!/bin/bash
# postStartCommand, as the remote user: check what onCreate set up, note a gh
# that isn't logged in, then report what the hooks recorded. A missing login
# is a note, not a failure: a container in CI has none.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
# shellcheck source=pending_failures.sh
. "$here/pending_failures.sh"
# shellcheck source=fix_volume_owner.sh
. "$here/fix_volume_owner.sh"
id=gh-config
mount=/mnt/enchantments/gh-config

# A later step can replace the link, and a root container sharing the volume
# leaves files this user can't change.
if ! pending_failures "$id"; then
  [ "$HOME/.config/gh" -ef "$mount" ] \
    || record_failure "$id" "$HOME/.config/gh isn't linked to gh-config, so" \
      "gh's login won't persist; move it aside, then run: bash" \
      "$here/onCreate.sh"
  owns_volume "$mount" \
    || record_failure "$id" "$mount holds files you don't own, so gh may" \
      "fail to save its login; run: sudo chown -R $(id -un) $mount"
fi
if [ "$HOME/.config/gh" -ef "$mount" ] && command -v gh >/dev/null \
  && ! gh auth token >/dev/null 2>&1; then
  echo "$id: gh isn't logged in: run 'gh auth login'; the login then" \
    "survives rebuilds" >&2
fi
report_failures "$id"
