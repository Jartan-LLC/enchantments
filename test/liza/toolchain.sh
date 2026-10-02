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
no_skill_links_into_volume() {
  local link
  for link in ~/.claude/skills/*; do
    [ -L "$link" ] || continue
    [[ "$(readlink -f "$link")" != /mnt/enchantments/liza/* ]] || return 1
  done
}
profiles_load_toolchain() {
  grep -q toolchain/env.sh ~/.bashrc && grep -q toolchain/env.sh ~/.profile
}
hook() { # command-substring
  jq -e --arg c "$1" \
    'any(.hooks[]?[]?.hooks[]?; .command | contains($c))' \
    .claude/settings.local.json
}
check "liza runs from PATH" liza version
for tool in rg rtk; do
  check "$tool runs from PATH" "$tool" --version
done
check "Liza is activated for the clone" activated
check "the shell profiles load the toolchain" profiles_load_toolchain
check "git status is clean" test -z "$(git status --porcelain)"
check "no skill in claude-data links into the volume" \
  no_skill_links_into_volume
check "core.hooksPath is unset" test -z "$(git config core.hooksPath)"
check "bash-policy's hook is in the local settings" hook bash-policy
# shellcheck disable=SC2016 # a jq program
check "context7 is registered at local scope" \
  jq -e --arg p "$PWD" --arg c "$HOME/.liza/bin/context7-mcp" \
  '.projects[$p].mcpServers.context7.command == $c' ~/.claude.json
check "AGENT_TOOLS.md is the toolchain's" \
  grep -q "staged by liza-toolchain" ~/.liza/AGENT_TOOLS.md
check "no failures recorded" \
  test -z "$(ls "$HOME"/.cache/enchantments/*.failures* 2>/dev/null)"
check "the smoke test passes" bash smoke-test.sh

reportResults
