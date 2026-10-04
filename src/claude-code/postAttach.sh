#!/bin/bash
# postAttachCommand, as the remote user: refresh Claude Code's plugins and the
# marketplaces they come from, so the newest versions load on the next session.
# Best-effort: a network hiccup never blocks attaching.

# claude switches a terminal stdin to raw mode, which stops it when it runs
# outside the terminal's foreground group, as under timeout. Hooks read no
# input.
exec </dev/null
command -v claude >/dev/null && command -v jq >/dev/null || exit 0
root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# claude-data holds every project's installs: update user-scope plugins, and
# this project's at project and local scope. Claude records a local install
# under the workspace folder but keeps settings at the repo root, which differ
# when the workspace is a subfolder, so match either. One "id scope" line per
# plugin.
plugins=$(timeout -k 10 60 claude plugins list --json 2>/dev/null \
  | jq -r --arg w "$PWD" --arg r "$root" '
    if type == "array" then .[] else empty end | objects
    | select(.id and (.scope == "user" or .projectPath == $w
      or .projectPath == $r))
    | "\(.id) \(.scope)"' 2>/dev/null)

marketplaces=$(printf '%s\n' "$plugins" \
  | sed -n 's/^[^@ ]*@\([^ ]*\) .*/\1/p' | sort -u)
for marketplace in $marketplaces; do
  timeout -k 10 60 claude plugins marketplace update "$marketplace" \
    >/dev/null 2>&1
done
while read -r plugin_id scope; do
  [ -n "$plugin_id" ] || continue
  timeout -k 10 60 claude plugins update "$plugin_id" --scope "$scope" \
    >/dev/null 2>&1
done <<<"$plugins"
exit 0
