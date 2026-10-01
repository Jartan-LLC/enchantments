#!/bin/bash
set -e
source dev-container-features-test-lib

# initializeCommand left a root-owned file in claude-data, so Docker didn't reseed the volume
# from the mount point: the Feature's sudo chown had to fix it.
check "claude-data and its contents belong to the user" test "$(stat -c %U ~/.claude ~/.claude/.seed)" = "vscode
vscode"
check "no failures recorded" test -z "$(ls "$HOME"/.cache/enchantments/*.failures* 2>/dev/null)"

reportResults
