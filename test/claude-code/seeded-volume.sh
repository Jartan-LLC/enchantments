#!/bin/bash
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

# initializeCommand left claude-data's top directory the user's, as a container
# of this user leaves it, and a root-owned .seed and claude.json inside, as a
# root container does: the Feature's sudo chown had to fix them, and keep the
# claude.json.
mount=/mnt/enchantments/claude-data
check "claude-data and its contents belong to the user" \
  test "$(stat -c %U "$mount" "$mount/.seed" "$mount/claude.json")" \
  = "$(printf 'vscode\nvscode\nvscode')"
check "an existing claude.json is kept" \
  jq -e '.seeded == true' "$HOME/.claude.json"
check "no failures recorded" \
  test -z "$(ls "$HOME"/.cache/enchantments/*.failures* 2>/dev/null)"

reportResults
