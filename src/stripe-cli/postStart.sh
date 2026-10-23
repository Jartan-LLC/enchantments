#!/bin/bash
# postStartCommand, as the remote user: say while the image has no stripe.
id=stripe-cli
[ -x /usr/local/bin/stripe ] \
  || echo "Warning: $id: stripe isn't installed: the image build couldn't" \
    "install it, and its log says why" >&2
exit 0
