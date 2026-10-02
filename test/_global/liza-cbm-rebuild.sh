#!/bin/bash
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

# test-features.sh runs this scenario twice on the same volumes. The marker,
# set before any assertion, tells pass 2 from pass 1 and holds pass 1's
# workspace; pass 2 leaves its own, which test-features.sh checks.
marker=/mnt/enchantments/liza/.rebuild-pass1
if [ -e "$marker" ]; then
  pass1_workspace=$(cat "$marker")
  touch /mnt/enchantments/liza/.rebuild-pass2
else
  pass1_workspace=
  echo "$PWD" >"$marker"
fi

# The CLI copies the test files into the workspace after create.
printf '%s\n' '/*.sh' /scenarios.json /dev-container-features-test-lib \
  >>.git/info/exclude

cbm=$HOME/.local/bin/codebase-memory-mcp
share=/usr/local/share/enchantments
activated() {
  [ "$(readlink -f CLAUDE.local.md)" = "$(readlink -f ~/.liza/CORE.md)" ] \
    && test -f "$(git rev-parse --git-path liza)/activation.json"
}
no_rtk_or_bash_policy_hook() {
  [ -f .claude/settings.local.json ] \
    && ! jq -r '.hooks[]?[]?.hooks[]?.command' .claude/settings.local.json \
    | grep -Eq 'bin/(rtk|bash-policy) '
}
registered_for() { # workspace
  jq -e --arg p "$1" --arg c "$cbm" \
    '.projects[$p].mcpServers["codebase-memory-mcp"].command == $c' \
    ~/.claude.json
}
no_failures() {
  test -z "$(ls "$HOME"/.cache/enchantments/*.failures* 2>/dev/null)"
}
clean() { test -z "$(git status --porcelain)"; }

# initializeCommand seeded a user-scope entry, as claude-data holds today.
check "the seeded user-scope entry is still there" \
  jq -e '.mcpServers["codebase-memory-mcp"].command == "/old"' ~/.claude.json
check "codebase-memory-mcp is registered for this workspace" \
  registered_for "$PWD"
check "claude sees the local entry" \
  bash -c 'claude mcp get codebase-memory-mcp | grep -q "Local config"'
check "codebase-memory-mcp runs" "$cbm" --version
check "Liza is activated for the clone" activated
check "AGENT_TOOLS.md is the minimal one" \
  grep -q "liza-toolchain is absent" ~/.liza/AGENT_TOOLS.md
check "no rtk or bash-policy hook" no_rtk_or_bash_policy_hook
check "git status is clean" clean
check "no failures recorded" no_failures

if [ -n "$pass1_workspace" ]; then
  # A fresh container on the populated volumes, whose pins all held.
  check "Liza is installed" test -x /mnt/enchantments/liza/libexec/liza
  check "nothing was reinstalled" \
    test -z "$(find /mnt/enchantments/liza/bin /mnt/enchantments/liza/libexec \
      -newer "$marker" ! -type d 2>/dev/null)"
  for tool in liza rg liza-activate liza-deactivate; do
    check "$tool is in ~/.local/bin" test -x ~/.local/bin/"$tool"
  done
  check "liza runs" liza version
  check "rg runs" rg --version
  check "liza-activate runs" liza-activate
  check "liza-deactivate --tools runs" liza-deactivate --tools
  check "pass 1's registration is kept" registered_for "$pass1_workspace"
fi

# A rebuild re-runs updateContentCommand against the persisting workspace.
check "liza's updateContent re-runs" bash "$share/liza/updateContent.sh"
check "codebase-memory-mcp's updateContent re-runs" \
  bash "$share/codebase-memory-mcp/updateContent.sh"
check "Liza is still activated" activated
check "git status is still clean" clean
check "still no failures recorded" no_failures

reportResults
