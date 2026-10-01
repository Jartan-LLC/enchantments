#!/bin/bash
# updateContentCommand, as the remote user, in the workspace: turn on auto-indexing, then
# register the MCP server at local scope for this workspace, unless Liza's toolchain, whose
# graph tools replace it, is here too.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
id=codebase-memory-mcp
bin=$HOME/.local/bin/codebase-memory-mcp
claude=$HOME/.local/bin/claude
markers=/usr/local/share/enchantments

[ -x "$bin" ] || exit 0  # onCreate recorded why
# The setting lives in ~/.cache, which a rebuild resets.
"$bin" config set auto_index true >/dev/null || record_failure "$id" "couldn't turn on auto_index"

if [ -d "$markers/liza" ] && [ -d "$markers/liza-toolchain" ]; then
    "$claude" mcp remove --scope local "$id" >/dev/null 2>&1
elif [ ! -d "$markers/claude-code" ]; then
    record_failure "$id" "claude-code absent: the MCP server isn't registered"
elif [ ! -L "$HOME/.claude.json" ] && [ "$HOME" != /home/vscode ]; then
    record_failure "$id" "claude-data is mounted at /home/vscode/.claude, not in \$HOME ($HOME): the MCP server isn't registered"
elif [ ! -L "$HOME/.claude.json" ]; then
    record_failure "$id" "$HOME/.claude.json isn't linked into claude-data (see claude-code's report): the MCP server isn't registered"
elif [ ! -x "$claude" ]; then
    record_failure "$id" "claude isn't installed (see claude-code's report): the MCP server isn't registered"
else
    # Replace our own local entry: a second add fails, and `mcp get` can't tell it from a
    # user-scope one.
    "$claude" mcp remove --scope local "$id" >/dev/null 2>&1
    "$claude" mcp add --scope local "$id" -- "$bin" >/dev/null \
        || record_failure "$id" "registering the MCP server failed; retry from the workspace folder: bash $here/updateContent.sh"
fi
