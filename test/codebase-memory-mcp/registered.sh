#!/bin/bash
set -e
source dev-container-features-test-lib

# shellcheck source=../../src/codebase-memory-mcp/pins.sh
. /usr/local/share/enchantments/codebase-memory-mcp/pins.sh
bin=$HOME/.local/bin/codebase-memory-mcp

check "the pinned release is installed" bash -c "'$bin' --version | grep -qwF '${CBM_TAG#v}'"
# shellcheck disable=SC2016 # a jq program
check "registered at local scope for this workspace" \
    jq -e --arg p "$PWD" --arg b "$bin" '.projects[$p].mcpServers["codebase-memory-mcp"].command == $b' ~/.claude.json
check "not registered at user scope" jq -e '.mcpServers["codebase-memory-mcp"] == null' ~/.claude.json
check "claude sees the local entry" bash -c 'claude mcp get codebase-memory-mcp | grep -q "Local config"'
check "auto_index is on" bash -c "'$bin' config list | grep -Eiq 'auto_index.*true'"
check "no skill, agent or hook in claude-data" \
    test -z "$(ls -d ~/.claude/skills/codebase-memory* ~/.claude/agents/codebase-memory* ~/.claude/hooks/cbm-* 2>/dev/null)"
check "no cbm hook in the user settings" bash -c '! grep -qs cbm- ~/.claude/settings.json'
check "no failures recorded" test -z "$(ls "$HOME"/.cache/enchantments/*.failures* 2>/dev/null)"

# shellcheck source=../../src/codebase-memory-mcp/fetch_verified.sh
. /usr/local/share/enchantments/codebase-memory-mcp/fetch_verified.sh
payload=$(mktemp) && echo payload >"$payload"
dest=$(mktemp -u)
refuses_wrong_digest() {
    ! fetch_verified "file://$payload" "$(printf '0%.0s' {1..64})" "$dest" && [ ! -e "$dest" ] && [ ! -e "$dest.part" ]
}
accepts_right_digest() {
    fetch_verified "file://$payload" "$(sha256sum "$payload" | cut -c1-64)" "$dest" && cmp -s "$payload" "$dest"
}
check "fetch_verified refuses a wrong digest and leaves nothing" refuses_wrong_digest
check "fetch_verified accepts the right digest" accepts_right_digest

reportResults
