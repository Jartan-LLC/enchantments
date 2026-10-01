## How it works

- **At create:** it links `~/.claude.json` into the `claude-data` volume, so your login and settings survive rebuilds, then runs Anthropic's native installer as you. Claude lands in `~/.local/bin` and updates itself.
- **At each start:** it warns when more than one `claude` is on `PATH`, such as an npm install or another Feature's. The one that runs first may not be this one.
- **At each attach:** it refreshes your user-scope plugins and this project's, with their marketplaces.

## Image requirements

- **Remote user `vscode`, with home `/home/vscode`.** Feature mounts take only literal paths. On images with another user (`javascript-node`, `typescript-node`, `universal`), Claude is installed in that user's home, off `PATH`, and its login doesn't persist: the volume is mounted at `/home/vscode/.claude`, not in `$HOME`.
- **Debian-based, with `bash`, `curl`, `jq` and `git`.** On any other image this Feature installs nothing, and the image still builds.
- **`sudo` is optional.** It's used only to take ownership of a shared volume another container left with a different owner; without it, the Feature warns.

## When something fails

Every hook exits 0, so a failure never stops the container's later setup. This Feature records each one in `~/.cache/enchantments/claude-code.failures`, and prints them when the container next starts. Re-run a hook as yourself with `bash /usr/local/share/enchantments/claude-code/<hook>.sh`.
