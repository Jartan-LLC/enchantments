#!/bin/bash
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

# No gh here, so there's no login to check.
mount=/mnt/enchantments/gh-config
check "gh-config is mounted" mountpoint -q "$mount"
check ".config/gh links to it" test "$(readlink -f ~/.config/gh)" = "$mount"
check "the volume belongs to the user" test "$(stat -c %U "$mount")" = vscode
check "no failures recorded" \
  test -z "$(ls "$HOME"/.cache/enchantments/*.failures* 2>/dev/null)"

# Each start checks what onCreate set up again.
hooks=/usr/local/share/enchantments/gh-config
unlinked=$(mktemp -d)
HOME=$unlinked bash "$hooks/postStart.sh" 2>/dev/null
check "an unlinked .config/gh is reported at start" \
  grep -q "/.config/gh isn't linked" \
  "$unlinked/.cache/enchantments/gh-config.failures.reported"
sudo -n touch "$mount/.root-owned"
bash "$hooks/postStart.sh" 2>/dev/null
check "a root-owned file in gh-config is reported at start" \
  grep -q "holds files you don't own" \
  ~/.cache/enchantments/gh-config.failures.reported
sudo -n rm "$mount/.root-owned"

reportResults
