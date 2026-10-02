#!/bin/bash
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

# The CLI copies the test files into the workspace after create.
printf '%s\n' '/*.sh' /scenarios.json /dev-container-features-test-lib \
  >>.git/info/exclude

activated() {
  [ "$(readlink -f CLAUDE.local.md)" = "$(readlink -f ~/.liza/CORE.md)" ] \
    && test -f "$(git rev-parse --git-path liza)/activation.json"
}
hook() { # command-substring
  jq -e --arg c "$1" \
    'any(.hooks[]?[]?.hooks[]?; .command | contains($c))' \
    .claude/settings.local.json
}

# Declaring codebase-memory-mcp is the consumer's choice, so it's registered
# alongside the toolchain.
check "codebase-memory-mcp is registered at local scope" \
  bash -c 'claude mcp get codebase-memory-mcp | grep -q "Local config"'
check "context7 is registered" bash -c 'claude mcp get context7 >/dev/null'
check "Liza is activated for the clone" activated
check "bash-policy's hook is in the local settings" hook bash-policy
check "git status is clean" test -z "$(git status --porcelain)"
check "no failures recorded" \
  test -z "$(ls "$HOME"/.cache/enchantments/*.failures* 2>/dev/null)"

reportResults
