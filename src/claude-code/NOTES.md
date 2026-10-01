## How it works

- **When the container is created,** Claude Code is installed in your home folder with Anthropic's native installer, and keeps itself up to date. Your login and settings live in the `claude-data` volume, mounted at `/mnt/enchantments/claude-data` and linked from `~/.claude` and `~/.claude.json`, so they survive rebuilds and are shared by every container that uses this Feature.
- **Each time the container starts,** you're warned if more than one `claude` is on `PATH`, such as one installed with npm. Only one of them runs, and it may not be this one.
- **Each time VS Code attaches,** your user plugins and this project's plugins are updated, along with their marketplaces.

## Image requirements

- Debian-based, with `curl` and `jq`.

## When something fails

The container still starts, and what went wrong is printed the next time it starts. To retry a step, run it from the workspace folder: `bash /usr/local/share/enchantments/claude-code/<hook>.sh`.
