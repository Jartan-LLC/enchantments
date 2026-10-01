#!/bin/bash
# updateContentCommand, as the remote user, in the workspace: add the grimoire
# marketplace and install the plugins at local scope, keyed to this clone. User
# scope would reach every container sharing claude-data; project scope would
# change a tracked file.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
plugins='' plugins_invalid=''
# shellcheck source=/dev/null # written by install.sh
. "$here/options.sh"
id=grimoire
claude=$HOME/.local/bin/claude
claude_json=/mnt/enchantments/claude-data/claude.json
none="no plugins installed"
retry="retry from the workspace folder: bash $here/updateContent.sh"

if [ -n "$plugins_invalid" ]; then
  record_failure "$id" "the plugins option must be comma-separated plugin" \
    "names; nothing installed"
  exit 0
elif [ -z "$plugins" ]; then
  exit 0
elif [ ! -d /usr/local/share/enchantments/claude-code ]; then
  record_failure "$id" "claude-code absent: $none"
  exit 0
elif [ ! "$HOME/.claude.json" -ef "$claude_json" ]; then
  record_failure "$id" "$HOME/.claude.json isn't linked into claude-data" \
    "(see claude-code's report): $none"
  exit 0
elif [ ! -x "$claude" ]; then
  record_failure "$id" "claude isn't installed (see claude-code's report):" \
    "$none"
  exit 0
elif ! command -v jq >/dev/null; then
  record_failure "$id" "jq isn't installed, so declined plugins can't be" \
    "read: $none"
  exit 0
fi

# The local settings file is per clone, so git status stays clean. Liza records
# its own slashed line, and removes only that, so the two never collide.
line=.claude/settings.local.json
if exclude=$(git rev-parse --git-path info/exclude 2>/dev/null) \
  && ! grep -qxF "$line" "$exclude" 2>/dev/null; then
  {
    mkdir -p "$(dirname "$exclude")" \
      && { [ ! -s "$exclude" ] || [ -z "$(tail -c1 "$exclude")" ] \
        || echo >>"$exclude"; } \
      && echo "$line" >>"$exclude"
  } || record_failure "$id" "couldn't add $line to $exclude"
fi

# Claude keeps both settings files at the repo root, even for a workspace in a
# subfolder.
settings=$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.claude

# A repo declines a plugin by committing it as false, a clone by `claude plugins
# disable --scope local`. Reinstalling would set the clone's key back to true,
# so neither is touched.
declined() { # plugin
  local file
  for file in "$settings/settings.json" "$settings/settings.local.json"; do
    [ -f "$file" ] \
      && jq -e --arg k "$1@$id" '.enabledPlugins[$k] == false' "$file" \
        >/dev/null 2>&1 \
      && return 0
  done
  return 1
}

# A repo that pins the marketplace to a ref keeps it: a local declaration
# without one would follow the default branch instead.
ref=$(jq -r '.extraKnownMarketplaces.grimoire.source.ref // empty' \
  "$settings/settings.json" 2>/dev/null)
if ! timeout 300 "$claude" plugins marketplace add \
  "Jartan-LLC/grimoire${ref:+#$ref}" --scope local >/dev/null; then
  record_failure "$id" "adding the grimoire marketplace failed; $retry"
  exit 0
fi
IFS=, read -ra wanted <<<"$plugins"
for plugin in "${wanted[@]}"; do
  declined "$plugin" && continue
  timeout 300 "$claude" plugins install "$plugin@$id" --scope local >/dev/null \
    || record_failure "$id" "installing $plugin failed; $retry"
done
