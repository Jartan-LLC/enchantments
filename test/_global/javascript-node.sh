#!/bin/bash
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

# Every Feature works for a user other than vscode: the volumes are linked
# into this home, and the tools are on PATH.
links() {
  [ "$(readlink -f ~/.claude)" = /mnt/enchantments/claude-data ] \
    && [ "$(readlink -f ~/.claude.json)" \
      = /mnt/enchantments/claude-data/claude.json ] \
    && test -f ~/.claude.json \
    && [ "$(readlink -f ~/.config/gh)" = /mnt/enchantments/gh-config ]
}
local_plugins() {
  claude plugins list --json | jq -c --arg p "$PWD" '[.[]
    | select(.scope == "local" and .projectPath == $p
      and (.id | endswith("@grimoire")))
    | .id] | sort'
}
check "claude runs from PATH" claude --version
check "the claude on PATH is in this home" \
  test "$(readlink -f "$(command -v claude)")" \
  = "$(readlink -f "$HOME/.local/bin/claude")"
check "the volumes are linked into this home" links
check "the grimoire plugins install at local scope" \
  test "$(local_plugins | jq length)" = 5
check "codebase-memory-mcp is registered" \
  bash -c 'claude mcp get codebase-memory-mcp | grep -q "Local config"'
check "codebase-memory-mcp runs from PATH" codebase-memory-mcp --version
check "this home is node's" test "$HOME" = /home/node
check "no failures recorded" \
  test -z "$(ls "$HOME"/.cache/enchantments/*.failures* 2>/dev/null)"

reportResults
