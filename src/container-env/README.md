
# Per-device environment variables (container-env)

Exports environment variables from the container-env volume, a .env file and one file per variable, into login shells and VS Code, so per-device values never go in a repo.

## Example Usage

```json
"features": {
    "ghcr.io/jartan-llc/enchantments/container-env:1": {}
}
```



## Setting variables

Values live in the `container-env` volume, mounted at `/mnt/enchantments/container-env`. Every container on this Docker host that has the Feature shares it, so each device keeps its own values and no repo holds them. Write them from any of those containers, in either form:

- **One file per variable.** The file's name is the variable's name. Its contents, minus trailing newlines, are the value, used as is, with no quoting or escaping. Use this form for secrets and multi-line values:

  ```bash
  cd /mnt/enchantments/container-env
  printf '%s' 'http://10.0.0.5:3456' >ANTHROPIC_BASE_URL
  printf 'x-api-key: <key>\nx-team: core\n' >ANTHROPIC_CUSTOM_HEADERS
  ```

- **A `.env` file** at `/mnt/enchantments/container-env/.env`, read by direnv's dotenv parser (`https://github.com/direnv/direnv`). It takes `KEY=value` lines, `export`, `#` comments, single and double quotes, `\n` inside double quotes, and `${VAR:-default}`. A line it can't parse leaves the whole file unloaded.

When a variable is set both ways, the file's value wins.

A new login shell picks up a change straight away. VS Code takes the values when it starts in the container, so restart the container for VS Code and the processes it starts.

## How it works

- **When the image is built,** a pinned direnv is installed, and `/etc/profile.d/container-env.sh` makes every login shell load the volume. VS Code takes its environment from a login shell (its `userEnvProbe`, `loginInteractiveShell` by default), so its terminals, tasks and extensions get the values too.
- **Each time the container starts,** problems with the volume are printed: a `.env` that doesn't parse, a file whose name isn't a variable name, and a variable that the `.env` sets but a file overrides.

## Limits

- **Only shells that read `/etc/profile` load the values:** `sh` and `bash` login shells, and whatever VS Code starts. zsh on Debian doesn't read it, and neither does a non-login shell such as a plain `docker exec`.
- **Removing a variable takes effect when the container restarts.** Until then, shells started from VS Code inherit the old value.
- **A tool's own configuration can override an exported value,** as an `env` block in a tool's settings file can. If a value doesn't take, check the tool's settings.
- **Every container on the device can change the values,** `PATH` included. See the trust boundary guide: `https://github.com/Jartan-LLC/enchantments/blob/main/docs/trust-boundary.md`.

## Why there are no options

Option values would be stored in the image and printed in the build log, VS Code's Settings Sync would copy them to every device, and the devcontainer CLI changes them before a Feature sees them (`https://github.com/devcontainers/cli/issues/1324`).

## Removal

Remove the Feature; the volume stays. `docker volume rm container-env` deletes the values.

## Image requirements

- Debian-based, with bash and `curl`.

## When something fails

The container still starts, and what went wrong is printed the next time it starts. To retry a step, run it from the workspace folder: `bash /usr/local/share/enchantments/container-env/<hook>.sh`.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/Jartan-LLC/enchantments/blob/main/src/container-env/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
