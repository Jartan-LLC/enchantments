#!/bin/bash
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

bin=/usr/local/bin/stripe
check "stripe runs from PATH" \
  bash -c "stripe --version | grep -q '^stripe version '"
check "the stripe on PATH is the Feature's" test "$(command -v stripe)" = "$bin"
check "the binary belongs to root" test "$(stat -c %U "$bin")" = root
# stripe login saves through the same write as this, offline.
check "stripe saves its config as the user" bash -c \
  "STRIPE_CLI_TELEMETRY_OPTOUT=1 stripe config --set color off \
    && grep -q 'color.*off' ~/.config/stripe/config.toml"

reportResults
