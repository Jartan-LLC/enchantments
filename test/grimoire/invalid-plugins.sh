#!/bin/bash
set -e
source dev-container-features-test-lib

check "the invalid option is reported" grep -q "plugins option must be" ~/.cache/enchantments/grimoire.failures.reported
check "options.sh holds only the invalid flag" test "$(cat /usr/local/share/enchantments/grimoire/options.sh)" = plugins_invalid=1
check "no plugin is installed" test "$(claude plugins list --json | jq '[.[] | select(.id | endswith("@grimoire"))] | length')" = 0

reportResults
