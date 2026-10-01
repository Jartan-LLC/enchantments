#!/bin/bash
set -e
source dev-container-features-test-lib

local_plugins() {
    claude plugins list --json | jq -c --arg p "$PWD" \
        '[.[] | select(.scope == "local" and .projectPath == $p and (.id | endswith("@grimoire"))) | .id] | sort'
}

check "exactly the plugins option's list is installed" test "$(local_plugins)" = '["gitwise@grimoire"]'
check "no failures recorded" test -z "$(ls "$HOME"/.cache/enchantments/*.failures* 2>/dev/null)"

reportResults
