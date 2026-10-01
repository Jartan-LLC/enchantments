#!/bin/bash
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

# Outside a git repository, only the per-clone steps are skipped.
check "Liza's global files are in the volume" test -f ~/.liza/CORE.md
check "the toolchain env is written" test -f ~/.liza/toolchain/env.sh
check "no contract is linked into the workspace" \
  test ! -e CLAUDE.local.md -a ! -L CLAUDE.local.md
check "no failures recorded" \
  test -z "$(ls "$HOME"/.cache/enchantments/*.failures* 2>/dev/null)"

reportResults
