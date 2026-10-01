#!/bin/bash
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

mount=/mnt/enchantments/gh-config
check "gh-config is mounted" mountpoint -q "$mount"
check ".config/gh links to it" test "$(readlink -f ~/.config/gh)" = "$mount"
check "the volume belongs to the user" test "$(stat -c %U "$mount")" = vscode
check ".config belongs to the user" test "$(stat -c %U ~/.config)" = vscode
check "the missing gh login is reported" grep -q "gh isn't logged in" \
  ~/.cache/enchantments/gh-config.failures.reported
check "nothing left unreported" \
  test -z "$(ls "$HOME"/.cache/enchantments/*.failures 2>/dev/null)"

reportResults
