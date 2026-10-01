#!/bin/bash
# onCreateCommand, as the remote user: link ~/.claude.json into claude-data first, so what
# the installer writes there persists, then install Claude Code with Anthropic's native
# installer. Unpinned on purpose: it updates itself.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
# shellcheck source=fix_volume_owner.sh
. "$here/fix_volume_owner.sh"
id=claude-code
volume=/home/vscode/.claude

if [ "$HOME" != /home/vscode ]; then
    record_failure "$id" "claude-data is mounted at $volume, not in \$HOME ($HOME): Claude is installed, but its login and settings won't persist"
else
    fix_volume_owner "$volume" \
        || record_failure "$id" "can't take ownership of $volume without passwordless sudo; run: sudo chown -R $(id -un) $volume"
    if [ ! -e "$volume/claude.json" ]; then
        if [ -f "$HOME/.claude.json" ] && [ ! -L "$HOME/.claude.json" ]; then
            cp "$HOME/.claude.json" "$volume/claude.json"
        else
            echo '{}' >"$volume/claude.json"
        fi
    fi
    if ! { [ -f "$volume/claude.json" ] && ln -sfn "$volume/claude.json" "$HOME/.claude.json"; }; then
        record_failure "$id" "can't link ~/.claude.json into claude-data, so Claude's settings won't persist"
    fi
fi

install_claude() {
    local script rc
    script=$(mktemp) || return 1
    curl -fsSL https://claude.ai/install.sh -o "$script" && bash "$script" </dev/null
    rc=$?
    rm -f "$script"
    return "$rc"
}
# Retried once: a network blip during create otherwise costs a rebuild.
if ! { install_claude || install_claude; } || [ ! -x "$HOME/.local/bin/claude" ]; then
    record_failure "$id" "Claude Code install failed; retry: curl -fsSL https://claude.ai/install.sh | bash"
fi
