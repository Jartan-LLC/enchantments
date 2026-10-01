#!/bin/bash
# updateContentCommand, as the remote user, in the workspace: add the grimoire marketplace and
# install the plugins at local scope, keyed to this clone. User scope would reach every
# container sharing claude-data; project scope would change a tracked file.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
plugins='' plugins_invalid=''
# shellcheck disable=SC1091 # written by install.sh
. "$here/options.sh"
id=grimoire
claude=$HOME/.local/bin/claude

if [ -n "$plugins_invalid" ]; then
    record_failure "$id" "the plugins option must be comma-separated plugin names; nothing installed"
    exit 0
elif [ ! -d /usr/local/share/enchantments/claude-code ]; then
    record_failure "$id" "claude-code absent: no plugins installed"
    exit 0
elif [ ! -L "$HOME/.claude.json" ]; then
    if [ "$HOME" != /home/vscode ]; then
        record_failure "$id" "claude-data is mounted at /home/vscode/.claude, not in \$HOME ($HOME): no plugins installed"
    else
        record_failure "$id" "$HOME/.claude.json isn't linked into claude-data (see claude-code's report): no plugins installed"
    fi
    exit 0
elif [ ! -x "$claude" ]; then
    record_failure "$id" "claude isn't installed (see claude-code's report): no plugins installed"
    exit 0
elif ! command -v jq >/dev/null; then
    record_failure "$id" "jq isn't installed, so declined plugins can't be read: no plugins installed"
    exit 0
fi
[ -n "$plugins" ] || exit 0

# The local settings file is per clone, so git status stays clean. Liza records its own
# slashed line, and removes only that, so the two never collide.
if exclude=$(git rev-parse --git-path info/exclude 2>/dev/null) \
    && ! grep -qxF .claude/settings.local.json "$exclude" 2>/dev/null; then
    { mkdir -p "$(dirname "$exclude")" \
        && { [ ! -s "$exclude" ] || [ -z "$(tail -c1 "$exclude")" ] || echo >>"$exclude"; } \
        && echo .claude/settings.local.json >>"$exclude"; } \
        || record_failure "$id" "couldn't add .claude/settings.local.json to $exclude"
fi

# A repo declines a plugin by committing it as false, a clone by `claude plugins disable
# --scope local`. Reinstalling would set the clone's key back to true, so neither is touched.
# Claude keeps both files at the repo root, even for a workspace in a subfolder.
settings=$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.claude
declined() {  # plugin
    local file
    for file in "$settings/settings.json" "$settings/settings.local.json"; do
        [ -f "$file" ] && jq -e --arg k "$1@$id" '.enabledPlugins[$k] == false' "$file" >/dev/null 2>&1 \
            && return 0
    done
    return 1
}

if ! timeout 300 "$claude" plugins marketplace add Jartan-LLC/grimoire --scope local >/dev/null; then
    record_failure "$id" "adding the grimoire marketplace failed; retry from the workspace folder: bash $here/updateContent.sh"
    exit 0
fi
IFS=, read -ra wanted <<<"$plugins"
for plugin in "${wanted[@]}"; do
    declined "$plugin" && continue
    timeout 300 "$claude" plugins install "$plugin@$id" --scope local >/dev/null \
        || record_failure "$id" "installing $plugin failed; retry from the workspace folder: bash $here/updateContent.sh"
done
