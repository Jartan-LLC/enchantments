#!/bin/bash
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

# The CLI copies the test files into the workspace after create.
printf '%s\n' '/*.sh' /scenarios.json /dev-container-features-test-lib \
  >>.git/info/exclude

# Every Feature works for a user other than vscode: the volumes are linked
# into this home, and the tools are on PATH.
links() {
  [ "$(readlink -f ~/.claude)" = /mnt/enchantments/claude-data ] \
    && [ "$(readlink -f ~/.claude.json)" \
      = /mnt/enchantments/claude-data/claude.json ] \
    && test -f ~/.claude.json \
    && [ "$(readlink -f ~/.config/gh)" = /mnt/enchantments/gh-config ] \
    && [ "$(readlink -f ~/.liza)" = /mnt/enchantments/liza ]
}
activated() {
  [ "$(readlink -f CLAUDE.local.md)" = "$(readlink -f ~/.liza/CORE.md)" ] \
    && test -f "$(git rev-parse --git-path liza)/activation.json"
}
hook() { # command-substring
  jq -e --arg c "$1" \
    'any(.hooks[]?[]?.hooks[]?; .command | contains($c))' \
    .claude/settings.local.json
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
check "liza runs from PATH" liza version
check "Liza is activated for the clone" activated
check "bash-policy's hook is in the local settings" hook bash-policy
# configure writes the profiles of the user's login shell.
check "the shell profile loads the toolchain" \
  grep -qs toolchain/env.sh ~/.bashrc ~/.zshrc
check "git status is clean" test -z "$(git status --porcelain)"
check "this home is node's" test "$HOME" = /home/node
check "no failures recorded" \
  test -z "$(ls "$HOME"/.cache/enchantments/*.failures* 2>/dev/null)"

reportResults
