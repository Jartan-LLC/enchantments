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
no_rtk_or_bash_policy_hook() {
  ! jq -r '.hooks[]?[]?.hooks[]?.command' .claude/settings.local.json \
    | grep -Eq 'bin/(rtk|bash-policy) '
}
reports=~/.cache/enchantments
check "Liza is activated for the clone" activated
check "git status is clean" test -z "$(git status --porcelain)"
check "AGENT_TOOLS.md is the minimal one" \
  grep -q "liza-toolchain is absent" ~/.liza/AGENT_TOOLS.md
check "no rtk or bash-policy hook" no_rtk_or_bash_policy_hook
# Without a code graph, Liza's contract falls back to rg: that's the one
# warning.
graph_rows="liza without liza-toolchain or codebase-memory-mcp: the"
graph_rows+=" contract's graph rows fall back to rg"
check "only the graph-rows warning is reported" \
  test "$(cat "$reports/liza.failures.reported")" = "$graph_rows"
check "nothing else recorded" \
  test "$(cd "$reports" && ls)" = liza.failures.reported
# The onCreateCommand registered context7 before activation: step 1 removes
# only the registration step 5 writes.
check "a context7 Liza didn't register survives" \
  bash -c 'claude mcp get context7 >/dev/null'
# shellcheck disable=SC2016 # a jq program
check "and keeps its command" \
  jq -e --arg p "$PWD" '.projects[$p].mcpServers.context7.command == "true"' \
  ~/.claude.json

# The commands on PATH, by name.
check "liza-deactivate runs" liza-deactivate
check "liza-deactivate unlinks the contract" \
  test ! -e CLAUDE.local.md -a ! -L CLAUDE.local.md
check "liza-deactivate drops the record" \
  test ! -e "$(git rev-parse --git-path liza)/activation.json"
check "git status is clean after liza-deactivate" \
  test -z "$(git status --porcelain)"
check "liza-activate runs" liza-activate
check "liza-activate links the contract again" activated
check "liza-activate records nothing" test ! -e "$reports/liza.failures"

reportResults
