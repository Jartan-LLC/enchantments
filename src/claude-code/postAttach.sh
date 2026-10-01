#!/bin/bash
# postAttachCommand, as the remote user: refresh this project's Claude Code plugins and the
# marketplaces they come from, so the newest versions load on the next session.
# Best-effort: a network hiccup never blocks attaching.
command -v claude >/dev/null && command -v jq >/dev/null || exit 0
project=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# claude-data holds every project's installs; update only user-scope plugins and this
# project's. One "id scope" line per plugin.
plugins=$(claude plugins list --json 2>/dev/null | jq -r --arg p "$project" '
    if type == "array" then .[] else empty end | objects
    | select(.id and (.scope == "user" or .projectPath == $p)) | "\(.id) \(.scope)"' 2>/dev/null)

for marketplace in $(printf '%s\n' "$plugins" | sed -n 's/^[^@ ]*@\([^ ]*\) .*/\1/p' | sort -u); do
    claude plugins marketplace update "$marketplace" >/dev/null 2>&1 || true
done
while read -r plugin_id scope; do
    [ -n "$plugin_id" ] || continue
    claude plugins update "$plugin_id" --scope "$scope" >/dev/null 2>&1 || true
done <<<"$plugins"
exit 0
