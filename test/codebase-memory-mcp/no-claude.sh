#!/bin/bash
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

bin=$HOME/.local/bin/codebase-memory-mcp
check "the binary is installed" "$bin" --version
check "auto_index is on" \
  bash -c "'$bin' config list | grep -Eiq 'auto_index.*true'"
check "the missing claude-code is reported" grep -q "claude-code absent" \
  ~/.cache/enchantments/codebase-memory-mcp.failures.reported
check "nothing left unreported" \
  test -z "$(ls "$HOME"/.cache/enchantments/*.failures 2>/dev/null)"

reportResults
