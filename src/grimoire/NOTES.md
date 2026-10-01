## How it works

Once the container is created, the grimoire marketplace is added and the plugins in the `plugins` option are installed for this clone. If the repo's `.claude/settings.json` pins the `Jartan-LLC/grimoire` marketplace to a `ref`, that ref is used. `.claude/settings.local.json` is added to the clone's `.git/info/exclude`, so `git status` stays clean.

Installing plugins needs the `claude-code` Feature. With an empty `plugins` list, nothing is installed.

The plugins' hooks run `node`, so you're warned at each start when it isn't on `PATH`. A Node that only your shell's startup files add, such as nvm's, isn't seen there; ignore the warning then.

## Declining a plugin

- **For a repo:** commit `"<id>@grimoire": false` under `enabledPlugins` in its `.claude/settings.json`.
- **For one clone:** run `claude plugins disable <id>@grimoire --scope local`.

Decline a plugin's dependents with it: praxis requires gitwise.

## Removal

Plugins outlive the Feature. In each clone, run `claude plugins uninstall <id>@grimoire --scope local` for each plugin you drop, whether you remove the Feature or shorten `plugins`. To remove the Feature, also run `claude plugins marketplace remove grimoire --scope local`, then remove the Feature. Keep `--scope local`: without it, that command also edits the committed `.claude/settings.json`.

## Image requirements

- Debian-based, with `jq`.
- `node` on `PATH`, from a Feature or a system install.

## When something fails

The container still starts, and what went wrong is printed the next time it starts. To retry a step, run it from the workspace folder: `bash /usr/local/share/enchantments/grimoire/<hook>.sh`.
