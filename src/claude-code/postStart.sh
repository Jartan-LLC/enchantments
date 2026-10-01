#!/bin/bash
# postStartCommand, as the remote user: warn about a second claude on PATH, then report what
# the create-time hooks recorded.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
id=claude-code

# Another install route (npm, another Feature) leaves a claude that can shadow this one.
claudes=$(which -a claude 2>/dev/null | xargs -r readlink -f | sort -u)
if [ "$(printf '%s' "$claudes" | grep -c .)" -gt 1 ]; then
    record_failure "$id" "more than one claude is on PATH, so the one that runs may not be this Feature's: $(printf '%s' "$claudes" | tr '\n' ' ')"
fi
report_failures "$id"
