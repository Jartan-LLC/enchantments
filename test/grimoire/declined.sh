#!/bin/bash
set -e
source dev-container-features-test-lib

# The CLI copies the test files into the workspace after create.
printf '%s\n' /*.sh /scenarios.json /dev-container-features-test-lib >>.git/info/exclude

local_plugins() {
    claude plugins list --json | jq -c --arg p "$PWD" \
        '[.[] | select(.scope == "local" and .projectPath == $p and (.id | endswith("@grimoire"))) | .id] | sort'
}
no_user_scope_grimoire() {
    [ ! -f ~/.claude/settings.json ] || jq -e '(.enabledPlugins // {} | keys | any(endswith("@grimoire")) | not)
        and .extraKnownMarketplaces.grimoire == null' ~/.claude/settings.json
}

# The fixture declines pythonica in the committed settings and claudivis in the clone's.
check "the defaults install at local scope, minus the declined" \
    test "$(local_plugins)" = '["gitwise@grimoire","praxis@grimoire","recursio@grimoire"]'
check "the clone's false is left false" jq -e '.enabledPlugins["claudivis@grimoire"] == false' .claude/settings.local.json
check "the local settings file is excluded" grep -qxF .claude/settings.local.json .git/info/exclude
check "git status is clean" test -z "$(git status --porcelain)"
check "nothing grimoire at user scope" no_user_scope_grimoire
check "the missing node is reported" grep -q "need node on PATH" ~/.cache/enchantments/grimoire.failures.reported
check "nothing left unreported" test -z "$(ls "$HOME"/.cache/enchantments/*.failures 2>/dev/null)"

reportResults
