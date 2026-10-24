#!/bin/bash
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

mount=/mnt/enchantments/gh-config
check "gh-config is mounted" mountpoint -q "$mount"
check ".config/gh links to it" test "$(readlink -f ~/.config/gh)" = "$mount"
check "the volume belongs to the user" test "$(stat -c %U "$mount")" = vscode
check ".config belongs to the user" test "$(stat -c %U ~/.config)" = vscode
check "the missing gh login isn't recorded" \
  test -z "$(ls "$HOME"/.cache/enchantments/gh-config.failures* 2>/dev/null)"
check "each start notes it" bash -c "bash \
  /usr/local/share/enchantments/gh-config/postStart.sh 2>&1 \
  | grep -q \"gh isn't logged in\""
no_login_note_unlinked() {
  local out
  out=$(HOME=$(mktemp -d) bash \
    /usr/local/share/enchantments/gh-config/postStart.sh 2>&1)
  ! grep -q "logged in" <<<"$out"
}
check "with .config/gh unlinked, there's no login note" no_login_note_unlinked
check "nothing left unreported" \
  test -z "$(ls "$HOME"/.cache/enchantments/*.failures 2>/dev/null)"

reportResults
