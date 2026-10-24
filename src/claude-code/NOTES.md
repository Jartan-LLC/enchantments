## How it works

- **When the container is created,** Claude Code is installed in your home folder with Anthropic's native installer, and keeps itself up to date. Your login and settings live in the `claude-data` volume, mounted at `/mnt/enchantments/claude-data` and linked from `~/.claude` and `~/.claude.json`, so they survive rebuilds and are shared by every container that uses this Feature. Run `claude` and log in once.
- **Each time the container starts,** you're warned if more than one `claude` is on `PATH`, such as one installed with npm. Only one of them runs, and it may not be this one.
- **Each time VS Code attaches,** your user plugins and this project's plugins are updated, along with their marketplaces.

To declare it for every container you open, see `https://github.com/Jartan-LLC/enchantments#declaring-a-feature`.

## Image requirements

- Debian-based, with `curl` and `jq`.

## When something fails

The container still starts, and what went wrong is printed the next time it starts. To retry a step, run it from the workspace folder: `bash /usr/local/share/enchantments/claude-code/<hook>.sh`. If nothing was reported but it isn't set up, see `https://github.com/Jartan-LLC/enchantments/blob/main/docs/troubleshooting.md`.

## Removal

The `claude-data` volume stays for the other containers that use it. Once none does, delete it with `docker volume rm claude-data` (under Docker Compose, `<project>_claude-data`).
