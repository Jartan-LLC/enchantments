
# Liza (liza)

Liza, pinned and digest-checked, with ripgrep, activated locally for each clone.

## Example Usage

```json
"features": {
    "ghcr.io/jartan-llc/enchantments/liza:1": {}
}
```



## How it works

- **When the container is created,** the pinned Liza binary and ripgrep are checked against their sha256 and installed in this project's `liza-<devcontainerId>` volume, mounted at `/mnt/enchantments/liza` and linked from `~/.liza`. `liza`, `liza-activate`, `liza-deactivate` and `rg` go on `PATH`.
- **Then, in the workspace,** Liza's global files are refreshed to match its binary, and Liza is activated for this clone. Outside a git repository, only the clone's activation is skipped.

## Activation

`liza` on `PATH` passes every command to the real binary except `init`, which it keeps local to the clone:

| Liza writes | Where it lands |
|---|---|
| hooks and permissions (and the toolchain's rtk and bash-policy hooks) | `.claude/settings.local.json` |
| the contract | `CLAUDE.local.md` → `~/.liza/CORE.md` |
| skills | links in `.claude/skills/` |
| hook scripts, `.claudeignore` and other new files | excluded in `.git/info/exclude` |

- `liza-activate` activates the clone you're in, and passes its arguments to `liza init`.
- Liza is active in one worktree of a repo at a time. To move it, run `liza-deactivate` in the active worktree, then `liza-activate` in the other. Run `liza-deactivate` before `git worktree remove`.
- `~/.liza/libexec/liza init` bypasses the shim, and writes to the committed `.claude/settings.json` and to `~/.claude/CLAUDE.md`.
- If the project sets `waitFor` to a stage before `updateContentCommand`, wait for the creation log to show activation finished before starting Claude.
- Before a multi-agent `liza init`, add `.liza/`, `.worktrees/`, `claude.env`, `pi.env` and any adversarial-pairing directory, such as `.adversarial/`, to the project's `.gitignore`.

## Undoing activation

`liza-deactivate` removes exactly what activation recorded in the clone's git dir (`git rev-parse --git-path liza/activation.json`). A settings value you've changed since stays as you set it, and a file you've edited since is kept and named. A file of yours that `init` overwrote is restored, or saved beside it as `<name>.pre-liza` when you've edited Liza's version since. A failed run keeps everything, and running it again finishes the job.

## Removal

1. While the Feature is still declared, in each clone, run `liza-deactivate --tools` if `liza-toolchain` is declared, then `liza-deactivate`.
2. Remove the `liza` entry, and `liza-toolchain`'s if declared.
3. Remove the volume: `docker volume rm liza-<devcontainerId>`.

## Image requirements

- Debian-based, with `bash`, `curl`, `jq` and `git`.

## When something fails

The container still starts, and what went wrong is printed the next time it starts. To retry a step, run it from the workspace folder: `bash /usr/local/share/enchantments/liza/<hook>.sh`. `liza-activate` reports at once, and exits non-zero when something failed.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/Jartan-LLC/enchantments/blob/main/src/liza/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
