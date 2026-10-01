#!/bin/bash
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

local_plugins() {
  claude plugins list --json | jq -c --arg p "$PWD" '[.[]
    | select(.scope == "local" and .projectPath == $p
      and (.id | endswith("@grimoire")))
    | .id] | sort'
}

# The fixture commits a marketplace pinned to a ref, as grimoire and sonde do.
check "the local declaration keeps the committed ref" \
  jq -e '.extraKnownMarketplaces.grimoire.source.ref == "marketplace-v1.0.0"' \
  .claude/settings.local.json
check "the default plugins install at local scope" \
  test "$(local_plugins)" = "$(printf '"%s@grimoire"\n' \
    praxis gitwise claudivis recursio pythonica | jq -sc sort)"
check "no failures recorded" \
  test -z "$(ls "$HOME"/.cache/enchantments/*.failures* 2>/dev/null)"

reportResults
