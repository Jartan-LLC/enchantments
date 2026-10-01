#!/bin/bash
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

# The toolchain installs into liza's volume, so without liza it does nothing.
reports=~/.cache/enchantments
check "the missing liza is reported" \
  grep -qx "liza-toolchain without liza: nothing installed" \
  "$reports/liza-toolchain.failures.reported"
check "nothing else recorded" \
  test "$(cd "$reports" && ls)" = liza-toolchain.failures.reported
check "nothing is installed" test ! -e /mnt/enchantments/liza/bin

reportResults
