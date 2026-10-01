#!/bin/bash
# onCreateCommand, as the remote user: take ownership of the gh-config volume, and say so
# when gh isn't logged in.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
# shellcheck source=fix_volume_owner.sh
. "$here/fix_volume_owner.sh"
id=gh-config
volume=/home/vscode/.config/gh

if [ "$HOME" != /home/vscode ]; then
    record_failure "$id" "gh-config is mounted at $volume, not in \$HOME ($HOME): gh's login won't persist"
    exit 0
fi
fix_volume_owner "$volume" \
    || record_failure "$id" "can't take ownership of $volume without passwordless sudo; run: sudo chown -R $(id -un) $volume"
if command -v gh >/dev/null && ! gh auth status >/dev/null 2>&1; then
    record_failure "$id" "gh isn't logged in: run 'gh auth login'; the login then survives rebuilds"
fi
