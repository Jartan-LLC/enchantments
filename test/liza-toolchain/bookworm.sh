#!/bin/bash
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

# The CLI copies the test files into the workspace after create.
printf '%s\n' '/*.sh' /scenarios.json /dev-container-features-test-lib \
  >>.git/info/exclude

bin=/mnt/enchantments/liza/bin
reports=~/.cache/enchantments
on_path() { # tool
  [ "$(command -v "$1")" = "$bin/$1" ] && "$1" --version >/dev/null
}
hook() { # command-substring
  jq -e --arg c "$1" \
    'any(.hooks[]?[]?.hooks[]?; .command | contains($c))' \
    .claude/settings.local.json
}
no_hook() { ! hook "$1"; } # command-substring
# Offline, so it answers only from the pinned local model.
semble_answers() {
  # shellcheck source=/dev/null # written at create time
  (. ~/.liza/toolchain/env.sh \
    && HF_HUB_OFFLINE=1 semble search fixture "$PWD" --content all >/dev/null)
}
for tool in ast-grep yq stacklit scip-search functional-clusters mdtoc \
  bash-policy scip-python scip-typescript semble rg; do
  check "$tool runs from PATH" on_path "$tool"
done
check "context7's wrapper runs the private Node" \
  grep -q /mnt/enchantments/liza/lib/node/bin/node "$bin/context7-mcp"
check "semble answers from the local model" semble_answers
check "no Node, Go or uv lands on PATH" \
  bash -c '! command -v node && ! command -v go && ! command -v uv'
check "bash-policy's hook is in the local settings" hook bash-policy
# The onCreateCommand registered context7 before activation: step 5 keeps it.
# shellcheck disable=SC2016 # a jq program
check "a context7 registered before activation is kept" \
  jq -e --arg p "$PWD" '.projects[$p].mcpServers.context7.command == "true"' \
  ~/.claude.json
check "git status is clean" test -z "$(git status --porcelain)"

# rtk's only arm64 build needs glibc 2.39; bookworm has 2.36.
if [ "$(uname -m)" = aarch64 ]; then
  check "rtk is absent" test ! -e "$bin/rtk"
  check "the report names glibc and AGENT_TOOLS.md" \
    bash -c "grep -q 'glibc 2.39' $reports/liza-toolchain.failures.reported \
      && grep -q AGENT_TOOLS.md $reports/liza-toolchain.failures.reported"
  check "no rtk hook" no_hook "bin/rtk hook"
  check "nothing else recorded" \
    test "$(cd "$reports" && ls)" = liza-toolchain.failures.reported
else
  check "rtk runs from PATH" on_path rtk
  check "mdq runs from PATH" on_path mdq
  check "rtk's hook is in the local settings" hook "bin/rtk hook"
  check "no failures recorded" \
    test -z "$(ls "$HOME"/.cache/enchantments/*.failures* 2>/dev/null)"
fi

reportResults
