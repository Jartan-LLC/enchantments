Log in once with `gh auth login`. The login then lives in the `gh-config` volume, which survives rebuilds and is shared by every container that mounts it. When `gh` is installed but not logged in at container creation, the Feature reports it at the next start.

## Image requirements

- **Remote user `vscode`, with home `/home/vscode`.** Feature mounts take only literal paths. On images with another user (`javascript-node`, `typescript-node`, `universal`), the volume is mounted at `/home/vscode/.config/gh`, not in `$HOME`, so the login doesn't persist.
- **Debian-based, with `bash`, `curl`, `jq` and `git`.** On any other image this Feature installs nothing, and the image still builds.
- **`sudo` is optional.** It's used only to take ownership of a shared volume another container left with a different owner; without it, the Feature warns.

## When something fails

Every hook exits 0, so a failure never stops the container's later setup. This Feature records each one in `~/.cache/enchantments/gh-config.failures`, prints them when the container next starts, then renames the file to `gh-config.failures.reported`. Re-run a hook as yourself, from the workspace folder, with `bash /usr/local/share/enchantments/gh-config/<hook>.sh`.
