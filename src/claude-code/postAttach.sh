#!/bin/bash
# postAttachCommand, as the remote user: refresh this project's Claude Code plugins and the
# marketplaces they come from, so the newest versions load on the next session.
# Best-effort: a network hiccup never blocks attaching.
command -v claude >/dev/null && command -v jq >/dev/null || exit 0
root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# claude-data holds every project's installs; update only user-scope plugins and this
# project's. Claude records a local install under the workspace folder but keeps settings
# at the repo root, which differ when the workspace is a subfolder, so match either.
# One "id scope" line per plugin.
plugins=$(timeout 60 claude plugins list --json 2>/dev/null | jq -r --arg w "$PWD" --arg r "$root" '
    if type == "array" then .[] else empty end | objects
    | select(.id and (.scope == "user" or .projectPath == $w or .projectPath == $r)) | "\(.id) \(.scope)"' 2>/dev/null)

for marketplace in $(printf '%s\n' "$plugins" | sed -n 's/^[^@ ]*@\([^ ]*\) .*/\1/p' | sort -u); do
    timeout 60 claude plugins marketplace update "$marketplace" >/dev/null 2>&1 || true
done
while read -r plugin_id scope; do
    [ -n "$plugin_id" ] || continue
    timeout 60 claude plugins update "$plugin_id" --scope "$scope" >/dev/null 2>&1 || true
done <<<"$plugins"
exit 0
