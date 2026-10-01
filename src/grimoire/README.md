
# grimoire plugins (grimoire)

Installs plugins from the grimoire Claude Code marketplace at local scope, for this clone only.

## Example Usage

```json
"features": {
    "ghcr.io/jartan-llc/enchantments/grimoire:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| plugins | Comma-separated grimoire plugins to install. A plugin the repo's or the clone's Claude settings set to false is skipped. | string | praxis,gitwise,claudivis,recursio,pythonica |

## How it works

In the workspace, after every Feature's install, it adds the grimoire marketplace and installs the `plugins` option's list at local scope, for this clone only. User scope would reach every container sharing `claude-data`, and project scope would change a tracked file. It adds `.claude/settings.local.json` to the clone's `.git/info/exclude`, so `git status` stays clean.

It needs the `claude-code` Feature. The plugins' hooks run `node`, so `node` must be on `PATH` when the container starts, from a Feature or a system install; otherwise the Feature says so at each start. A Node that only your shell's startup files add, such as a hand-installed nvm, isn't seen there, so ignore that warning in that case.

## Declining a plugin

- **For a repo:** commit `"<id>@grimoire": false` under `enabledPlugins` in its `.claude/settings.json`. That holds under `defaultFeatures` too.
- **For one clone:** run `claude plugins disable <id>@grimoire --scope local`, which survives rebuilds.

Either way, decline a plugin's dependents with it: praxis requires gitwise.

## Removal

Local-scope plugins, and their hooks, outlive the Feature. Whether you remove the Feature or narrow `plugins` (the option only adds), run `claude plugins uninstall <id>@grimoire --scope local` in each clone for each plugin dropped. To remove the Feature, then run `claude plugins marketplace remove grimoire --scope local` in each clone, and remove its entry. Without `--scope`, that command also edits a committed `.claude/settings.json`.

## Image requirements

- **Remote user `vscode`, with home `/home/vscode`.** Feature mounts take only literal paths. On images with another user (`javascript-node`, `typescript-node`, `universal`), nothing is installed: `claude-data` is mounted at `/home/vscode/.claude`, not in `$HOME`.
- **Debian-based, with `bash`, `curl`, `jq` and `git`.** On any other image this Feature installs nothing, and the image still builds.
- **`sudo` is optional.** It's used only to take ownership of a shared volume another container left with a different owner; without it, the Feature warns.

## When something fails

Every hook exits 0, so a failure never stops the container's later setup. This Feature records each one in `~/.cache/enchantments/grimoire.failures`, and prints them when the container next starts. Re-run a hook as yourself with `bash /usr/local/share/enchantments/grimoire/<hook>.sh`.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/Jartan-LLC/enchantments/blob/main/src/grimoire/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
