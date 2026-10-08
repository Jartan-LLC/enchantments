## Declaring it for every container

Declare it in VS Code's `dev.containers.defaultFeatures`, so every container you open gets it and no repo has to name it: `https://github.com/Jartan-LLC/enchantments#declaring-a-feature`.

## Setting variables

Values live in the `container-env` volume at `/mnt/enchantments/container-env`, shared by every container on this Docker host that mounts it. Write them from any of those containers, in either form:

- **One file per variable,** for secrets and multi-line values. The file's name is the variable's name, and its contents, minus trailing newlines, are the value as is:

  ```bash
  cd /mnt/enchantments/container-env
  printf '%s' 'http://10.0.0.5:3456' >ANTHROPIC_BASE_URL
  printf 'x-api-key: <key>\nx-team: core\n' >ANTHROPIC_CUSTOM_HEADERS
  ```

- **A `.env` file** at `/mnt/enchantments/container-env/.env`, in dotenv syntax: `KEY=value` lines, `export`, `#` comments, quotes, `\n` inside double quotes, and `${VAR:-default}`. direnv's parser reads it (`https://github.com/direnv/direnv`), and one line it can't parse leaves the whole file unloaded. Outside single quotes, a dollar sign expands from the shell's environment: single-quote a literal one, and don't make a value refer to itself, as `PATH=$PATH:/opt/x` grows in each nested login shell.

When both set a variable, the file wins, and a value from the volume replaces one the shell already has, such as one from `containerEnv`. The Feature takes no options: a value given as an option would be saved in the image and, from `defaultFeatures`, copied to your other devices by Settings Sync.

## When values apply

- **Login shells** (`sh` and `bash`) load the values each time they start, through `/etc/profile.d/container-env.sh`.
- **VS Code** loads them from your login shell when it starts in the container, and passes them to its terminals, tasks and extensions. Restart the container after a change.
- **A removed variable** stays in VS Code, and in the shells it starts, until the container restarts.
- **zsh on Debian, and non-login shells** such as a plain `docker exec`, don't load them. When your login shell is zsh, neither does VS Code.

## When a value doesn't show up

1. Read the warnings printed when the container starts, or print them again with `bash /usr/local/share/enchantments/container-env/postStart.sh`. They name:
   - a `.env` that doesn't parse or can't be read, and each `.env` line bash rejects;
   - a file whose name isn't a variable name, or that can't be read;
   - a name bash won't set, such as `UID`;
   - a value over 128 KiB, and values that would take the environment past half the system's limit for a program's arguments and environment together;
   - a missing direnv.

   Folders, files whose names start with a dot other than `.env`, and a `.env`'s `PWD` and `SHLVL`, which bash sets itself, are ignored without a warning.
2. Check where you're reading it: see When values apply.
3. Check the tool's own settings: a tool can override an exported value, as Claude Code's `env` setting does.

## Security

Every container on this Docker host that mounts the volume can read the values and change them, `PATH` included: code that runs in one of them can read your secrets and run in the others. See the trust boundary guide: `https://github.com/Jartan-LLC/enchantments/blob/main/docs/trust-boundary.md`.

## Removal

Remove the Feature; the volume stays. `docker volume rm container-env` deletes the values.

## Image requirements

- Debian-based, with bash and `curl`.

## When something fails

The container still starts, and what went wrong is printed the next time it starts. To retry a step, run it from the workspace folder: `bash /usr/local/share/enchantments/container-env/<hook>.sh`.
