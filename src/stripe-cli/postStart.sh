#!/bin/bash
# postStartCommand, as the remote user: say while the image has no stripe,
# then report what the create-time hooks recorded.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
id=stripe-cli

[ -x /usr/local/bin/stripe ] \
  || echo "Warning: $id: stripe isn't installed, since the image build" \
    "couldn't download it; rebuild the container to retry" >&2
report_failures "$id"
