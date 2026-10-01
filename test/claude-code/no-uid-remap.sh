#!/bin/bash
set -e
source dev-container-features-test-lib

# Without the uid remap's chown -R of the home, any build-time path left root-owned shows.
for dir in ~/.claude ~/.config ~/.config/gh ~/.local/bin; do
    check "$dir belongs to the user" test "$(stat -c %U "$dir")" = vscode
done
check "no failures recorded" test -z "$(ls "$HOME"/.cache/enchantments/*.failures* 2>/dev/null)"

reportResults
