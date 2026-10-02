#!/bin/bash
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

# test-features.sh runs this scenario twice on the same volumes. The marker,
# set before any assertion, tells pass 2 from pass 1; pass 2 leaves its own,
# which test-features.sh checks.
marker=/mnt/enchantments/liza/.rebuild-pass1
if [ -e "$marker" ]; then
  pass=2
  touch /mnt/enchantments/liza/.rebuild-pass2
else
  pass=1
  touch "$marker"
fi

# The CLI copies the test files into the workspace after create.
printf '%s\n' '/*.sh' /scenarios.json /dev-container-features-test-lib \
  >>.git/info/exclude

local_plugins() {
  claude plugins list --json | jq -c --arg p "$PWD" '[.[]
    | select(.scope == "local" and .projectPath == $p
      and (.id | endswith("@grimoire")))
    | .id] | sort'
}
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
hook() { # command-substring
  jq -e --arg c "$1" \
    'any(.hooks[]?[]?.hooks[]?; .command | contains($c))' \
    .claude/settings.local.json
}
profiles_load_toolchain() {
  grep -q toolchain/env.sh ~/.bashrc && grep -q toolchain/env.sh ~/.profile
}
no_failures() {
  test -z "$(ls "$HOME"/.cache/enchantments/*.failures* 2>/dev/null)"
}
clean() { test -z "$(git status --porcelain)"; }

check "the five U1 Features are applied" \
  test "$(cd /usr/local/share/enchantments && echo *)" \
  = "claude-code gh-config grimoire liza liza-toolchain"
plugins='["claudivis@grimoire","gitwise@grimoire","praxis@grimoire",'
plugins+='"pythonica@grimoire","recursio@grimoire"]'
check "the grimoire plugins install at local scope" \
  test "$(local_plugins)" = "$plugins"
check "Liza is activated for the clone" activated
check "bash-policy's hook is in the local settings" hook bash-policy
check "codebase-memory-mcp isn't registered here" \
  bash -c '! claude mcp get codebase-memory-mcp'
check "the shell profiles load the toolchain" profiles_load_toolchain
check "no skill in claude-data links into the volume" \
  no_skill_links_into_volume
check "core.hooksPath is unset" test -z "$(git config core.hooksPath)"
check "git status is clean" clean
check "no failures recorded" no_failures

if [ "$pass" = 2 ]; then
  # A fresh container on the populated volumes.
  for tool in liza rg liza-activate liza-deactivate; do
    check "$tool is in ~/.local/bin" test -x ~/.local/bin/"$tool"
  done
  check "liza runs" liza version
  check "rg runs" rg --version
  check "liza-deactivate --tools runs" liza-deactivate --tools
fi

# Activation picks its SCIP languages from the files git lists, so it runs
# again once there are Python and TypeScript roots; the commit then runs
# Liza's index hooks.
echo 'print("hello")' >main.py
echo '{"compilerOptions": {"strict": true}}' >tsconfig.json
echo 'export const greeting: string = "hello";' >index.ts
git add main.py tsconfig.json index.ts
check "liza-activate runs" liza-activate
git -c user.name=t -c user.email=t@t commit -qm roots
for index in stacklit.json python.scip typescript.scip \
  functional-clusters.json; do
  check "the commit writes $index" test -f "$index"
done
check "git status is clean after the commit" clean

# A rebuild re-runs updateContentCommand against the persisting workspace.
check "liza's updateContent re-runs" \
  bash /usr/local/share/enchantments/liza/updateContent.sh
check "Liza is still activated" activated
check "git status is still clean" clean
check "still no failures recorded" no_failures

reportResults
