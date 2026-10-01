#!/bin/bash
set -e
source dev-container-features-test-lib

# initializeCommand left root-owned files in claude-data, so Docker didn't reseed the volume
# from the mount point: the Feature's sudo chown had to fix it, and keep the claude.json.
check "claude-data and its contents belong to the user" test "$(stat -c %U ~/.claude ~/.claude/.seed)" = "vscode
vscode"
check "an existing claude.json is kept" jq -e '.seeded == true' "$HOME/.claude.json"
check "no failures recorded" test -z "$(ls "$HOME"/.cache/enchantments/*.failures* 2>/dev/null)"

reportResults
