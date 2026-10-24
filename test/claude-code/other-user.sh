#!/bin/bash
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

# initializeCommand left claude-data's top directory the user's, a root-owned
# .root-owned, as a root container does, and a 0600 .other-owned of uid 4242,
# as another user's container does. Create takes back root's file only, and
# reports the other user's, without stopping the rest of the setup.
mount=/mnt/enchantments/claude-data
check "root's file is taken back" \
  test "$(stat -c %U "$mount/.root-owned")" = vscode
check "the other user's file stays theirs" \
  test "$(stat -c %u:%a "$mount/.other-owned")" = 4242:600
check "the other user's file is reported" \
  grep -q "holds files of uid 4242" \
  "$HOME"/.cache/enchantments/claude-code.failures*
check "the links are still made" \
  test -f "$(readlink -f "$HOME/.claude.json")"

reportResults
