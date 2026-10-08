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
check "the shell profiles load the toolchain" \
  grep -q toolchain/env.sh ~/.bashrc
check "git status is clean" test -z "$(git status --porcelain)"
check "this home is root's" test "$HOME" = /root

container_env_loads() {
  printf x >/mnt/enchantments/container-env/ROOT_CHECK \
    && [ "$(env -i PATH=/usr/bin:/bin bash -lc "printf %s \"\$ROOT_CHECK\"")" \
      = x ]
}
check "container-env loads in root's login shells" container_env_loads

# initializeCommand seeded both shared volumes as the runner's user, as a
# non-root container leaves them. Root never re-owns one: that would lock the
# non-root containers out of their 0600 files.
keeps_owner() { # mount
  local owner
  owner=$(stat -c %u "$1/.seed")
  [ "$owner" != 0 ] && [ "$(stat -c %u "$1")" = "$owner" ]
}
check "claude-data keeps its owner" keeps_owner /mnt/enchantments/claude-data
check "gh-config keeps its owner" keeps_owner /mnt/enchantments/gh-config

# base:trixie has no node, so grimoire's warning is the only one.
reports=~/.cache/enchantments
check "grimoire reports the missing node" \
  grep -q "need node on PATH" "$reports/grimoire.failures.reported"
check "nothing else recorded" \
  test "$(cd "$reports" && ls)" = grimoire.failures.reported

reportResults
