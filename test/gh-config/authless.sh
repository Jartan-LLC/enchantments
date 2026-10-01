#!/bin/bash
set -e
source dev-container-features-test-lib

check "gh-config is mounted" mountpoint -q ~/.config/gh
check "the volume belongs to the user" test "$(stat -c %U ~/.config/gh)" = vscode
check "its parent belongs to the user" test "$(stat -c %U ~/.config)" = vscode
check "the missing gh login is reported" grep -q "gh isn't logged in" ~/.cache/enchantments/gh-config.failures.reported
check "nothing left unreported" test -z "$(ls "$HOME"/.cache/enchantments/*.failures 2>/dev/null)"

reportResults
