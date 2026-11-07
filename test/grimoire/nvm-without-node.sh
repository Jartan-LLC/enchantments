#!/bin/bash
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

# The image puts nvm's current/bin on PATH but installs no Node into it.
check "node is grimoire's" \
  test "$(command -v node)" = /usr/local/share/enchantments/grimoire/bin/node
check "grimoire's node runs" node -e 'process.exit(0)'
check "only node is on PATH from grimoire" \
  test "$(ls /usr/local/share/enchantments/grimoire/bin)" = node
check "the plugins option's list is installed" \
  bash -c 'claude plugins list --json \
    | jq -e "any(.[]; .id == \"gitwise@grimoire\" and .scope == \"local\")"'
check "no failures recorded" \
  test -z "$(ls "$HOME"/.cache/enchantments/*.failures* 2>/dev/null)"

reportResults
