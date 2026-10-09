#!/bin/bash
# postStartCommand, as the remote user: warn about a second claude on PATH and
# about a base URL Claude would reach with the shared login, then report what
# the create-time hooks recorded.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
id=claude-code

# Another install route (npm, another Feature) leaves a claude that can shadow
# this one. /usr/local/bin/claude links to this one, so resolve before counting.
claudes=$(which -a claude 2>/dev/null | xargs -r readlink -f | sort -u)
if [ "$(printf '%s' "$claudes" | grep -c .)" -gt 1 ]; then
  record_failure "$id" "more than one claude is on PATH, so the one that runs" \
    "may not be the claude-code Feature's: ${claudes//$'\n'/ }"
fi

# Without a token in the environment, Claude authenticates with the login in
# claude-data and refreshes it, even when the base URL supplies the login. A
# token there outranks that login, which Claude then never refreshes.
host=${ANTHROPIC_BASE_URL-}
host=${host#*://}
host=${host%%[/?#]*}
host=${host##*@} # userinfo can hold a secret
host=${host%%:*}
host=${host,,}
if [ -n "$host" ] && [ "$host" != api.anthropic.com ] \
  && [ -z "${CLAUDE_CODE_OAUTH_TOKEN-}${ANTHROPIC_AUTH_TOKEN-}" ] \
  && [ -z "${ANTHROPIC_API_KEY-}" ]; then
  record_failure "$id" "ANTHROPIC_BASE_URL sends Claude to $host, but no" \
    "token is set in the environment, so Claude uses and refreshes the" \
    "login shared through claude-data. If $host supplies the login, set" \
    "CLAUDE_CODE_OAUTH_TOKEN to any value wherever ANTHROPIC_BASE_URL is set"
fi
report_failures "$id"
