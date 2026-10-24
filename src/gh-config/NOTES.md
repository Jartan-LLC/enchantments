## How it works

- **When the container is created,** `~/.config/gh` is linked to the `gh-config` volume, mounted at `/mnt/enchantments/gh-config`, so the GitHub CLI's login survives rebuilds and is shared by every container that uses this Feature. Files another user's container left in the volume stay theirs, and you're warned (`https://github.com/Jartan-LLC/enchantments/blob/main/docs/persistence.md#sharing-a-volume`).
- **Each time the container starts,** files a container running as root left in the volume are made yours again where passwordless sudo is available. You're warned if they can't be, if another user's container left files there (`https://github.com/Jartan-LLC/enchantments/blob/main/docs/persistence.md#sharing-a-volume`), in which case nothing is taken, or if `~/.config/gh` no longer links to the volume. If `gh` is installed but isn't logged in, you're told so, without counting it as a failure: run `gh auth login` once.

To declare it for every container you open, see `https://github.com/Jartan-LLC/enchantments#declaring-a-feature`.

## Image requirements

- Debian-based.
- `gh` on `PATH`, from a Feature or the image.

## When something fails

The container still starts, and what went wrong is printed the next time it starts. To retry a step, run it from the workspace folder: `bash /usr/local/share/enchantments/gh-config/<hook>.sh`. If nothing was reported but it isn't set up, see `https://github.com/Jartan-LLC/enchantments/blob/main/docs/troubleshooting.md`.

## Removal

The `gh-config` volume stays for the other containers that use it. Once none does, delete it with `docker volume rm gh-config` (under Docker Compose, `<project>_gh-config`).
