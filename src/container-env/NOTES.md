## Declaring it

Declare it in VS Code's `dev.containers.defaultFeatures`, so every container you open gets it and no repo has to name it: `https://github.com/Jartan-LLC/enchantments#declaring-a-feature`. The Feature takes no options: a value given as an option would be saved in the image and, from `defaultFeatures`, copied to your other devices by Settings Sync.

## How it works

- **When the image is built,** direnv is installed, and `/etc/profile.d/container-env.sh` is added to load the values.
- **When the container is created,** the `container-env` volume, mounted at `/mnt/enchantments/container-env`, is made yours, unless another user's container left files in it: you're warned instead (`https://github.com/Jartan-LLC/enchantments/blob/main/docs/persistence.md#sharing-a-volume`).
- **Each time the container starts,** problems with the values are reported, and files a container running as root left in the volume are made yours again where passwordless sudo is available, or you're warned. You're also warned if another user's container left files there.
- **Each login shell** (`sh` and `bash`) loads the values when it starts.
- **VS Code** loads them from your login shell when it starts in the container, and passes them to its terminals, tasks and extensions. Restart the container after a change. A removed variable stays in VS Code, and in the shells it starts, until then.
- **zsh on Debian, and non-login shells** such as a plain `docker exec`, don't load them. When your login shell is zsh, neither does VS Code.

## Setting variables

Values live in the `container-env` volume at `/mnt/enchantments/container-env`, shared by every container on this Docker host that mounts it. Write them from any of those containers, in either form:

- **One file per variable,** for secrets and multi-line values. The file's name is the variable's name, and its contents, minus trailing newlines, are the value as is:

  ```bash
  cd /mnt/enchantments/container-env
  printf '%s' 'http://10.0.0.5:3456' >ANTHROPIC_BASE_URL
  printf 'x-api-key: <key>\nx-team: core\n' >ANTHROPIC_CUSTOM_HEADERS
  ```

- **A `.env` file** at `/mnt/enchantments/container-env/.env`, in dotenv syntax: `KEY=value` lines, `export`, `#` comments, quotes, `\n` inside double quotes, and `${VAR:-default}`. direnv's parser reads it (`https://github.com/direnv/direnv`), and one line it can't parse leaves the whole file unloaded. Outside single quotes, a dollar sign expands from the `.env`'s earlier lines or the shell's environment, so single-quote a literal one. Don't make a value refer to itself: `PATH=$PATH:/opt/x` grows in each nested login shell.

When both set a variable, the file wins, and a value from the volume replaces one the shell already has, such as one from `containerEnv`.

## Security

Every container on this Docker host that mounts the volume can read the values and change them, `PATH` included: code that runs in one of them can read your secrets and run in the others. See the trust boundary guide: `https://github.com/Jartan-LLC/enchantments/blob/main/docs/trust-boundary.md`.

## Image requirements

- Debian-based, with `curl`.

## When a value doesn't show up

1. Read the warnings printed when the container starts, or print them again with `bash /usr/local/share/enchantments/container-env/postStart.sh`. They name:
   - a `.env` that doesn't parse or can't be read, and each `.env` line bash rejects;
   - a file whose name isn't a variable name, or that can't be read;
   - a name bash won't set, such as `UID`;
   - a value over 128 KiB, and values that would take the environment past half the system's limit for a program's arguments and environment together;
   - a missing direnv;
   - files a container running as root left in the volume, where they can't be made yours again;
   - files another user's container left in the volume.

   They also note each variable a file overrides in the `.env`.

   Folders, files whose names start with a dot other than `.env`, and a `.env`'s `PWD` and `SHLVL`, which bash sets itself, are ignored without a warning.
2. Check where you're reading it: see How it works.
3. Check the tool's own settings: a tool can override an exported value, as Claude Code's `env` setting does.

## When something fails

The container still starts, and what went wrong is printed the next time it starts. To retry a step, run it from the workspace folder: `bash /usr/local/share/enchantments/container-env/<hook>.sh`. If nothing was reported but it isn't set up, see `https://github.com/Jartan-LLC/enchantments/blob/main/docs/troubleshooting.md`.

## Removal

The `container-env` volume stays, with its values, for the other containers that use it. Once none does, `docker volume rm container-env` (under Docker Compose, `<project>_container-env`) deletes them.
