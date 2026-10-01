
# codebase-memory-mcp (codebase-memory-mcp)

The codebase-memory-mcp code graph, installed from a pinned, digest-checked release and registered as an MCP server for this workspace only.

## Example Usage

```json
"features": {
    "ghcr.io/jartan-llc/enchantments/codebase-memory-mcp:1": {}
}
```



## How it works

- **At create:** it installs the pinned release into `~/.local/bin` after checking its sha256, and runs the binary's own installer with `--skip-config`, so nothing is written into the shared `claude-data`.
- **Then, in the workspace:** it turns on auto-indexing and registers the MCP server at local scope, for this workspace only. Declared with `liza` and `liza-toolchain`, it removes that registration instead: the toolchain's graph tools replace it.

Registration needs the `claude-code` Feature; without it, the binary is installed and the Feature says why it isn't registered.

## Removal

The local registration outlives the Feature. Run `claude mcp remove --scope local codebase-memory-mcp` in each clone, then remove the Feature's entry.

## Image requirements

- **Remote user `vscode`, with home `/home/vscode`.** Feature mounts take only literal paths. On images with another user (`javascript-node`, `typescript-node`, `universal`), the binary is installed but not registered: `claude-data` is mounted at `/home/vscode/.claude`, not in `$HOME`.
- **Debian-based, with `bash`, `curl`, `jq` and `git`.** On any other image this Feature installs nothing, and the image still builds.

## When something fails

Every hook exits 0, so a failure never stops the container's later setup. This Feature records each one in `~/.cache/enchantments/codebase-memory-mcp.failures`, and prints them when the container next starts. Re-run a hook as yourself with `bash /usr/local/share/enchantments/codebase-memory-mcp/<hook>.sh`.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/Jartan-LLC/enchantments/blob/main/src/codebase-memory-mcp/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
