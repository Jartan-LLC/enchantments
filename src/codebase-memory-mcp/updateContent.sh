#!/bin/bash
# updateContentCommand, as the remote user, in the workspace: turn on
# auto-indexing, then register the MCP server at local scope for this workspace.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
# shellcheck source=claude_ready.sh
. "$here/claude_ready.sh"
id=codebase-memory-mcp
bin=$HOME/.local/bin/codebase-memory-mcp
# claude switches a terminal stdin to raw mode, changing the terminal the hook
# runs in. Hooks read no input.
exec </dev/null

[ -x "$bin" ] || exit 0 # onCreate recorded why
# The setting lives in ~/.cache, which a rebuild resets.
"$bin" config set auto_index true >/dev/null \
  || record_failure "$id" "couldn't turn on auto_index"

if claude_ready "$id" "the MCP server isn't registered"; then
  # Replace our own local entry: a second add fails, and `mcp get` can't tell
  # it from a user-scope one.
  "$claude_bin" mcp remove --scope local "$id" >/dev/null 2>&1
  "$claude_bin" mcp add --scope local "$id" -- "$bin" >/dev/null \
    || record_failure "$id" "registering the MCP server failed; retry from" \
      "the workspace folder: bash $here/updateContent.sh"
fi
