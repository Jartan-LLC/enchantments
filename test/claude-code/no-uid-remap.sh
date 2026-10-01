#!/bin/bash
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

# Without the uid remap's chown -R of the home, a build-time path left
# root-owned shows. The mounts are re-owned at runtime too, so the home paths
# the hooks create are the checks that catch it.
for path in /mnt/enchantments/claude-data /mnt/enchantments/gh-config \
  ~/.config ~/.local/bin; do
  check "$path belongs to the user" test "$(stat -c %U "$path")" = vscode
done
check "no failures recorded" \
  test -z "$(ls "$HOME"/.cache/enchantments/*.failures* 2>/dev/null)"

reportResults
