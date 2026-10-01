#!/bin/bash
# postStartCommand, as the remote user: report what the create-time hooks
# recorded.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
report_failures gh-config
