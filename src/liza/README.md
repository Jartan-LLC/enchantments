
# Liza (liza)

Liza, pinned and digest-checked, with ripgrep, activated locally for each clone: its hooks, contract and skills stay out of committed files and out of other projects.

## Example Usage

```json
"features": {
    "ghcr.io/jartan-llc/enchantments/liza:1": {}
}
```



## How it works

- **When the container is created,** the pinned Liza binary and ripgrep are checked against their sha256 and installed in this project's `liza-<devcontainerId>` volume, mounted at `/mnt/enchantments/liza` and linked from `~/.liza`. `liza`, `liza-activate`, `liza-deactivate` and `rg` go on `PATH`.
- **Then, in the workspace,** Liza's global files are refreshed to match its binary, and Liza is activated for this clone. Activation writes only local files, so collaborators and CI are unaffected. Outside a git repository, only the clone's activation is skipped.
- **Declare it with `liza-toolchain` or `codebase-memory-mcp`.** Alone, the contract's code-graph rows fall back to `rg`, and the start-time report says so.
- **If the project sets `waitFor`** to a stage before `updateContentCommand`, VS Code connects before activation finishes: wait for the creation log to show it finished before starting Claude.

## Activation

`liza` on `PATH` passes every command to the real binary except `init`, which it keeps local to the clone:

| Liza writes | Where it lands |
|---|---|
| hooks and permissions (and the toolchain's rtk and bash-policy hooks) | `.claude/settings.local.json` |
| the contract | `CLAUDE.local.md` → `~/.liza/CORE.md` |
| skills | links in `.claude/skills/` |
| hook scripts, `.claudeignore` and other new files | excluded in `.git/info/exclude` |

`liza-activate` activates the clone you're in, and passes its arguments to `liza init`. `~/.liza/libexec/liza init` bypasses the shim, and writes to the committed `.claude/settings.json` and to `~/.claude/CLAUDE.md`, which every container sharing `claude-data` loads.

The shim works around liza-mas/liza issues [163](https://github.com/liza-mas/liza/issues/163) and [164](https://github.com/liza-mas/liza/issues/164).

A multi-agent `liza init` writes `.liza/` and `.worktrees/` at the repo root, and its provider overrides (`claude.env`, `pi.env`) sit there too. Add those to the project's `.gitignore`, with any adversarial-pairing directory such as `.adversarial/`; scaffold's `.gitignore` has a Liza section to copy.

## Undoing activation

`liza-deactivate` removes exactly what activation recorded in `.git/liza/activation.json`. A settings value you've changed since stays as you set it, and a file you've edited since is kept and named. A file of yours that `init` overwrote is restored, or saved beside it as `<name>.pre-liza` when you've edited Liza's version since. A failed run keeps everything, and running it again finishes the job.

## Removal

While the Feature is still declared, run `liza-deactivate` in each clone, and also `liza-deactivate --tools` if `liza-toolchain` is declared. Then remove both entries, then the volume. Otherwise `CLAUDE.local.md` and the local settings keep pointing into an unmounted `~/.liza`.

## Image requirements

- Debian-based, with `bash`, `curl`, `jq` and `git`.

## When something fails

The container still starts, and what went wrong is printed the next time it starts. To retry a step, run it from the workspace folder: `bash /usr/local/share/enchantments/liza/<hook>.sh`. `liza-activate` reports at once, and exits non-zero when something failed.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/Jartan-LLC/enchantments/blob/main/src/liza/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
