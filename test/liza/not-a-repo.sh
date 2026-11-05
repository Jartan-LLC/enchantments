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
# Without a clone, nothing ran Liza through the shim, so only activation's
# calls could have pointed it at the pinned catalog.
commit=$(sed -n "s/^LIZA_COMMIT='\(.*\)'$/\1/p" \
  /usr/local/share/enchantments/liza/pins.sh)
# shellcheck disable=SC2016 # a jq program
check "Liza read the pinned release's provider catalog" \
  jq -e --arg c "$commit" '.url == "https://raw.githubusercontent.com"
    + "/liza-mas/liza/\($c)/provider-catalog.yaml"' \
  ~/.liza/cache/provider-catalog.meta.json

reportResults
