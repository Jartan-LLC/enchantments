#!/bin/bash
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

# initializeCommand put ANTHROPIC_BASE_URL in container-env's volume. postStart
# gets it the way VS Code does, from the login shell, and must warn.
check "a proxy without a token is reported" grep -q \
  'ANTHROPIC_BASE_URL sends Claude to 10.0.0.5' \
  "$HOME/.cache/enchantments/claude-code.failures.reported"

reportResults
