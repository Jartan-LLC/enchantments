#!/bin/bash
# postStartCommand, as the remote user: check what onCreate set up and warn
# about a second claude on PATH, then report what the hooks recorded.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
# shellcheck source=start_checks.sh
. "$here/start_checks.sh"
id=claude-code
mount=/mnt/enchantments/claude-data

# A later step can replace a link, and a root container sharing the volume
# leaves files this user can't change.
if ! pending_failures "$id"; then
  [ "$HOME/.claude" -ef "$mount" ] \
    || record_at_start "$id" "$HOME/.claude isn't linked to claude-data, so" \
      "what Claude keeps there won't persist;" \
      "$(relink_advice "$HOME/.claude" "$here/onCreate.sh")"
  [ "$HOME/.claude.json" -ef "$mount/claude.json" ] \
    || record_at_start "$id" "$HOME/.claude.json isn't linked into" \
      "claude-data, so Claude's settings won't persist;" \
      "$(relink_advice "$HOME/.claude.json" "$here/onCreate.sh")"
  take_back_root_files "$id" "$mount" "Claude may fail to save there"
fi

# Another install route (npm, another Feature) leaves a claude that can shadow
# this one. /usr/local/bin/claude links to this one, so resolve before counting.
claudes=$(which -a claude 2>/dev/null | xargs -r readlink -f | sort -u)
if [ "$(printf '%s' "$claudes" | grep -c .)" -gt 1 ]; then
  record_at_start "$id" "more than one claude is on PATH, so the one that" \
    "runs may not be the claude-code Feature's: ${claudes//$'\n'/ }"
fi
report_failures "$id"
