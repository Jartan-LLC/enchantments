## How it works

- **When the container is created,** the pinned release is checked against its sha256 and installed in `~/.local/bin`. Its own installer also adds `~/.local/bin` to `PATH` in `~/.bashrc`.
- **Then, in the workspace,** auto-indexing is turned on, and the MCP server is registered with Claude Code for this workspace. Registering needs the `claude-code` Feature; without it, the binary is still installed.

## Removal

The registration outlives the Feature. In each clone, run `claude mcp remove --scope local codebase-memory-mcp`, then remove the Feature.

## Image requirements

- Debian-based, with `curl`.

## When something fails

The container still starts, and what went wrong is printed the next time it starts. To retry a step, run it from the workspace folder: `bash /usr/local/share/enchantments/codebase-memory-mcp/<hook>.sh`.
