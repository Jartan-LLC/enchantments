#!/bin/bash
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

# initializeCommand gave the volume to uid 4242, mode 0700, with a file in it,
# as another user's container leaves it. Create leaves it theirs, reporting it.
dir=/mnt/enchantments/container-env
check "the volume stays the other user's" \
  test "$(stat -c %u:%a "$dir")" = 4242:700
check "the other user's volume is reported" \
  grep -q "holds files of uid 4242" \
  "$HOME"/.cache/enchantments/container-env.failures*

reportResults
