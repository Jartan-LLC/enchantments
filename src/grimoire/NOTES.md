## How it works

- **Once the container is created, in the workspace,** the grimoire marketplace is added and the plugins in the `plugins` option are installed for this clone. If the repo's `.claude/settings.json` pins the `Jartan-LLC/grimoire` marketplace to a `ref`, that ref is used. `.claude/settings.local.json` is added to the clone's `.git/info/exclude`, so `git status` stays clean. Installing plugins needs the `claude-code` Feature. With an empty `plugins` list, nothing is installed.
- **Each time the container starts,** when `plugins` lists any, you're warned if `node` isn't on `PATH`, since the plugins' hooks run it. A Node that only your shell's startup files add, such as nvm's, isn't seen there; ignore the warning then.

To declare it for every container you open, see `https://github.com/Jartan-LLC/enchantments#declaring-a-feature`.

## Declining a plugin

- **For a repo:** commit `"<id>@grimoire": false` under `enabledPlugins` in its `.claude/settings.json`.
- **For one clone:** run `claude plugins disable <id>@grimoire --scope local`.

Decline a plugin's dependents with it: praxis requires gitwise.

## Image requirements

- Debian-based, with `jq`.
- `node` on `PATH`, from a Feature or a system install.

## When something fails

The container still starts, and what went wrong is printed the next time it starts. To retry a step, run it from the workspace folder: `bash /usr/local/share/enchantments/grimoire/<hook>.sh`. If nothing was reported but it isn't set up, see `https://github.com/Jartan-LLC/enchantments/blob/main/docs/troubleshooting.md`.

## Removal

Plugins outlive the Feature. While `claude-code` is still declared, in each clone, run `claude plugins uninstall <id>@grimoire --scope local` for each plugin you drop, whether you remove the Feature or shorten `plugins`. To remove the Feature, also run `claude plugins marketplace remove grimoire --scope local`, then remove the Feature from the project's config and from `defaultFeatures`. Keep `--scope local`: without it, that command also edits the committed `.claude/settings.json`. The `.claude/settings.local.json` line in the clone's `.git/info/exclude` stays; leave it while that file exists.
