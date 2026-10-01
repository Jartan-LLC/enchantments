#!/bin/bash
set -e
source dev-container-features-test-lib

# No gh here, so there's no login to check.
check "gh-config is mounted" mountpoint -q ~/.config/gh
check "the volume belongs to the user" test "$(stat -c %U ~/.config/gh)" = vscode
check "no failures recorded" test -z "$(ls "$HOME"/.cache/enchantments/*.failures* 2>/dev/null)"

reportResults
