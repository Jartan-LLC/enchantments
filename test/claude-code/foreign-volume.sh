#!/bin/bash
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

# initializeCommand gave claude-data to uid 4242, mode 0700, with a file in it,
# as another user's container leaves it. Create can't read it, so can't tell
# it's empty, and leaves it theirs, reporting it.
mount=/mnt/enchantments/claude-data
check "the volume stays the other user's" \
  test "$(stat -c %u:%a "$mount")" = 4242:700
check "and so does its file" \
  test "$(sudo -n stat -c %u "$mount/theirs")" = 4242
check "the other user's volume is reported" \
  grep -q "holds files of uid 4242" \
  "$HOME"/.cache/enchantments/claude-code.failures*

reportResults
