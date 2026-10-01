
# GitHub CLI login persistence (gh-config)

Keeps the GitHub CLI's login in the gh-config volume, so it survives rebuilds and is shared by every container that mounts it.

## Example Usage

```json
"features": {
    "ghcr.io/jartan-llc/enchantments/gh-config:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| probe | Throwaway | bool | true |

Log in once with `gh auth login`. The login then lives in the `gh-config` volume, which survives rebuilds and is shared by every container that mounts it. When `gh` is installed but not logged in, the Feature says so at the next start.

## Image requirements

- **Remote user `vscode`, with home `/home/vscode`.** Feature mounts take only literal paths. On images with another user (`javascript-node`, `typescript-node`, `universal`), the volume is mounted at `/home/vscode/.config/gh`, not in `$HOME`, so the login doesn't persist.
- **Debian-based, with `bash`, `curl`, `jq` and `git`.** On any other image this Feature installs nothing, and the image still builds.
- **`sudo` is optional.** It's used only to take ownership of a shared volume another container left with a different owner; without it, the Feature warns.

## When something fails

Every hook exits 0, so a failure never stops the container's later setup. This Feature records each one in `~/.cache/enchantments/gh-config.failures`, and prints them when the container next starts. Re-run a hook as yourself with `bash /usr/local/share/enchantments/gh-config/<hook>.sh`.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/Jartan-LLC/enchantments/blob/main/src/gh-config/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
