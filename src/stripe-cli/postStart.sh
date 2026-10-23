#!/bin/bash
# postStartCommand, as the remote user: say while the image has no stripe.
id=stripe-cli
[ -x /usr/local/bin/stripe ] \
  || echo "Warning: $id: stripe isn't installed, since the image build" \
    "couldn't download it; rebuild the container to retry" >&2
exit 0
