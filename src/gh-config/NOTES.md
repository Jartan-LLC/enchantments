## How it works

Log in once with `gh auth login`. The login lives in the `gh-config` volume, mounted at `/mnt/enchantments/gh-config` and linked from `~/.config/gh`, so it survives rebuilds and is shared by every container that uses this Feature. If `gh` is installed but not logged in when the container is created, you're told the next time it starts.

## Image requirements

- Debian-based.

## When something fails

The container still starts, and what went wrong is printed the next time it starts. To retry a step, run it from the workspace folder: `bash /usr/local/share/enchantments/gh-config/<hook>.sh`.
