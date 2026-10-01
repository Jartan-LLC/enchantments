#!/bin/bash
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

reported=~/.cache/enchantments/grimoire.failures.reported
check "the invalid option is reported" \
  grep -q "plugins option must be" "$reported"
check "options.sh holds only the invalid flag" \
  test "$(cat /usr/local/share/enchantments/grimoire/options.sh)" \
  = plugins_invalid=1
check "no node warning, since no plugin was asked for" \
  bash -c "! grep -q 'need node on PATH' '$reported'"
check "no plugin is installed" \
  test "$(claude plugins list --json \
    | jq '[.[] | select(.id | endswith("@grimoire"))] | length')" = 0

reportResults
