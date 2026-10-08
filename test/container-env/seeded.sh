#!/bin/bash
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

# initializeCommand left the volume's top directory the user's, as a container
# of this user leaves it, and a root-owned file inside, as a root container
# does: onCreate's sudo chown must fix it.
dir=/mnt/enchantments/container-env
check "the volume and its files belong to the user" \
  test "$(stat -c %U "$dir" "$dir/SEEDED")" = "$(printf 'vscode\nvscode')"
check "the user can replace a seeded value" \
  bash -c "printf mine >$dir/SEEDED"
check "the seeded value loads" test "$(
  env -i HOME="$HOME" PATH=/usr/bin:/bin bash -lc "printf %s \"\$SEEDED\""
)" = mine
check "no failures recorded" \
  test -z "$(ls "$HOME"/.cache/enchantments/*.failures* 2>/dev/null)"

reportResults
