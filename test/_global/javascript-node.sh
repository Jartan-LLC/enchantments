#!/bin/bash
set -e
source dev-container-features-test-lib

# The image's user is node, so the volumes' literal /home/vscode targets aren't in $HOME:
# Claude is installed, off PATH, and each Feature reports that its volume isn't usable.
check "claude is installed in the node user's home" "$HOME/.local/bin/claude" --version
for id in claude-code codebase-memory-mcp gh-config grimoire; do
    check "$id reports the volume outside \$HOME" \
        grep -q 'is mounted at /home/vscode' "$HOME/.cache/enchantments/$id.failures.reported"
done
check "nothing left unreported" test -z "$(ls "$HOME"/.cache/enchantments/*.failures 2>/dev/null)"

reportResults
