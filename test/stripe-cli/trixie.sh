#!/bin/bash
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

bin=/usr/local/bin/stripe
check "stripe runs from PATH" \
  bash -c "stripe --version | grep -q '^stripe version '"
check "the stripe on PATH is the Feature's" test "$(command -v stripe)" = "$bin"
check "the binary belongs to root" test "$(stat -c %U "$bin")" = root
mount=/mnt/enchantments/stripe-config
check "stripe-config is mounted" mountpoint -q "$mount"
check ".config/stripe links to it" \
  test "$(readlink -f ~/.config/stripe)" = "$mount"
check "the volume belongs to the user" test "$(stat -c %U "$mount")" = vscode
check "no failures recorded" \
  test -z "$(ls "$HOME"/.cache/enchantments/*.failures* 2>/dev/null)"

reportResults
