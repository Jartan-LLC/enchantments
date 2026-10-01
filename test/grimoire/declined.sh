#!/bin/bash
set -e
source dev-container-features-test-lib

# The CLI copies the test files into the workspace after create.
printf '%s\n' '/*.sh' /scenarios.json /dev-container-features-test-lib >>.git/info/exclude

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

# The hook again, from a subfolder of another repo, in a scratch HOME whose claude stub logs
# its calls.
fake=$(mktemp -d)
mkdir -p "$fake/.local/bin"
cat >"$fake/.local/bin/claude" <<STUB
#!/bin/bash
echo "\$*" >>"$fake/calls"
STUB
chmod +x "$fake/.local/bin/claude"
ln -s /dev/null "$fake/.claude.json"
repo=$(mktemp -d)
git -C "$repo" init -q && mkdir -p "$repo/sub" "$repo/.claude"
echo '{"enabledPlugins":{"claudivis@grimoire":false}}' >"$repo/.claude/settings.local.json"
printf 'last-line' >"$repo/.git/info/exclude"
(cd "$repo/sub" && HOME=$fake bash /usr/local/share/enchantments/grimoire/updateContent.sh) 2>/dev/null
check "from a subfolder, the plugin the repo root declines is skipped" bash -c "! grep -q 'install claudivis@grimoire' '$fake/calls'"
check "from a subfolder, the others install" grep -q 'install praxis@grimoire' "$fake/calls"
check "an exclude line without a newline stays whole" grep -qx last-line "$repo/.git/info/exclude"
check "the settings line is added on its own" grep -qxF .claude/settings.local.json "$repo/.git/info/exclude"

# Without jq, declined plugins can't be read, so nothing may install.
nojq=$(mktemp -d)
for tool in readlink dirname git grep mkdir tail timeout; do ln -s "$(command -v "$tool")" "$nojq/$tool"; done
: >"$fake/calls"
(cd "$repo/sub" && HOME=$fake PATH=$nojq /bin/bash /usr/local/share/enchantments/grimoire/updateContent.sh) 2>/dev/null
check "without jq, nothing installs" test ! -s "$fake/calls"
check "without jq, the failure is recorded" grep -q "jq isn't installed" "$fake/.cache/enchantments/grimoire.failures"

# An empty plugins list: no claude calls and nothing reported, though this image has no node.
empty=$(mktemp -d)
cp /usr/local/share/enchantments/grimoire/*.sh "$empty"/ && echo "plugins=''" >"$empty/options.sh"
: >"$fake/calls" && rm -rf "$fake/.cache"
(cd "$repo/sub" && HOME=$fake bash "$empty/updateContent.sh" && HOME=$fake bash "$empty/postStart.sh") 2>/dev/null
check "an empty list makes no claude call" test ! -s "$fake/calls"
check "an empty list reports nothing" test -z "$(ls -A "$fake/.cache/enchantments" 2>/dev/null)"

reportResults
