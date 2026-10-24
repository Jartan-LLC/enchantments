
# Claude Code (claude-code)

Claude Code, installed as the remote user with Anthropic's native installer so it updates itself, with its login and settings kept in the claude-data volume.

## Example Usage

```json
"features": {
    "ghcr.io/jartan-llc/enchantments/claude-code:1": {}
}
```



## Customizations

### VS Code Extensions

- `anthropic.claude-code`

## How it works

- **When the container is created,** Claude Code is installed in your home folder with Anthropic's native installer, and keeps itself up to date. Your login and settings live in the `claude-data` volume, mounted at `/mnt/enchantments/claude-data` and linked from `~/.claude` and `~/.claude.json`, so they survive rebuilds and are shared by every container that uses this Feature. Run `claude` and log in once.
- **Each time the container starts,** files a container running as root left in `claude-data` are made yours again where passwordless sudo is available. You're warned if they can't be, or if `~/.claude` or `~/.claude.json` no longer links into `claude-data`. You're also warned if more than one `claude` is on `PATH`, such as one installed with npm. Only one of them runs, and it may not be this one.
- **Each time VS Code attaches,** your user plugins and this project's plugins are updated, along with their marketplaces.

To declare it for every container you open, see `https://github.com/Jartan-LLC/enchantments#declaring-a-feature`.

## Image requirements

- Debian-based, with `curl` and `jq`.

## When something fails

The container still starts, and what went wrong is printed the next time it starts. To retry a step, run it from the workspace folder: `bash /usr/local/share/enchantments/claude-code/<hook>.sh`. If nothing was reported but it isn't set up, see `https://github.com/Jartan-LLC/enchantments/blob/main/docs/troubleshooting.md`.

## Removal

The `claude-data` volume stays for the other containers that use it. Once none does, delete it with `docker volume rm claude-data` (under Docker Compose, `<project>_claude-data`).


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/Jartan-LLC/enchantments/blob/main/src/claude-code/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
