
# Liza (liza)

Liza, activated locally for each clone, with ripgrep; both pinned and digest-checked.

## Example Usage

```json
"features": {
    "ghcr.io/jartan-llc/enchantments/liza:1": {}
}
```



## How it works

- **When the container is created,** the pinned Liza binary and ripgrep are checked against their sha256 and installed in this project's `liza-<devcontainerId>` volume, mounted at `/mnt/enchantments/liza` and linked from `~/.liza`. `liza`, `liza-activate`, `liza-deactivate` and `rg` go on `PATH`; `rg` only if `~/.local/bin` has no `rg` already. A pinned `pre-commit`, which Liza's multi-agent init needs, is installed there too unless one is already on `PATH`; it goes last on `PATH`, so one you install later is used instead.
- **Then, in the workspace,** Liza's global files are refreshed to match its binary, and Liza is activated for this clone. Outside a git repository, or in a checkout whose git dir isn't its own `.git`, such as a linked worktree or a submodule, only the clone's activation is skipped.
- **Each time the container starts,** you're warned if `~/.liza` is missing or isn't the volume, or if `~/.local/bin/rg` is missing or doesn't run.

To declare it for every container you open, see `https://github.com/Jartan-LLC/enchantments#declaring-a-feature`.

## Activation

`liza` on `PATH` passes every command to the real binary except `init`, which it keeps local to the clone:

| Liza writes | Where it lands |
|---|---|
| hooks and permissions (and the toolchain's rtk and bash-policy hooks) | `.claude/settings.local.json` |
| the contract | `CLAUDE.local.md` → `~/.liza/CORE.md`, or `.claude/CLAUDE.md` → `~/.liza/CORE.md` when `CLAUDE.local.md` is yours |
| skills | links in `.claude/skills/` |
| hook scripts, `.claudeignore` and other new files | excluded in `.git/info/exclude` |

- `liza init` replaces `.bash-policy.yaml` and `.claudeignore` without asking. Activation merges your edits to them with what Liza changed since the last activation. Yours stays as it is, with Liza's version beside it as `<name>.liza`, when the two conflict, when the file is yours from before Liza, or when you edited it in a clone an earlier version of this Feature activated. Activation's output names `<name>.liza` (the container creation log, when a lifecycle hook ran it), not the next start's report, and a later conflict replaces it, so take what you need from it before the next activation. If `liza init` fails or is interrupted, your version goes back. A symlink or directory at either path is left to `liza init`.
- `liza-activate` activates the clone you're in, and passes its arguments to `liza init`.
- Activation refuses when `CLAUDE.local.md` is your own file or symlink and `.claude/CLAUDE.md` is taken too, by your own file or one the project commits, and changes nothing.
- When the contract is at `.claude/CLAUDE.md`, Claude loads it only in the clone itself, not in a worktree inside it, such as a multi-agent task's in `.worktrees/`, and `liza agent` warns on each start that it finds no contract link. A multi-agent run needs the contract at `CLAUDE.local.md`: move yours aside and run `liza-activate`. From Liza v0.10.0, `liza use-system-prompt` is the other way: in a project that ran it, `liza agent` passes the contract to each Claude agent in its system prompt, and still warns.
- Liza is activated only in a repo's main checkout: from a linked worktree, `liza init` writes to the main checkout instead. `liza-activate` refuses in a checkout whose git dir isn't its own `.git`, such as a linked worktree or a submodule. `liza init` acts on the clone you're in, so `liza -C <dir> init` refuses when `<dir>` is outside that clone.
- `~/.liza/libexec/liza init` bypasses the shim, and writes to the committed `.claude/settings.json` and to `~/.claude/CLAUDE.md`.
- If the project sets `waitFor` to a stage before `updateContentCommand`, wait for the creation log to show activation finished before starting Claude.
- Before a multi-agent `liza init`, add `.liza/`, `.worktrees/`, `claude.env`, `pi.env` and any adversarial-pairing directory, such as `.adversarial/`, to the project's `.gitignore`.

## Undoing activation

`liza-deactivate` removes exactly what activation recorded in the clone's git dir (`git rev-parse --git-path liza/activation.json`). A settings value you've changed since stays as you set it, and a file you've edited since is kept and named. A file of yours that `init` overwrote is restored, or saved beside it as `<name>.pre-liza` when you've edited Liza's version since. A `.bash-policy.yaml` or `.claudeignore` that activation merged with your edits counts as edited. A copy of either file that an interrupted or failed activation left in the clone's git dir, and that differs from the file, goes beside it as `<name>.pre-liza`. A `<name>.pre-liza` already there is never replaced: when it differs from the copy, deactivation fails and names the copy, which stays in the clone's git dir. Your `CLAUDE.local.md`, if a killed activation left it in the clone's git dir, goes back in its place. A failed run keeps its record, and running it again finishes the job.

## Image requirements

- Debian-based, with `curl`, `jq` and `git`.

## When something fails

The container still starts, and what went wrong is printed the next time it starts. A merged `.bash-policy.yaml` or `.claudeignore`, or your version of one, that can't be written back after `liza init` is the exception: activation still succeeds, and the warning is only in its output (the container creation log, or `liza-activate`'s output). Your version stays in the clone's git dir, and the next activation refuses and names it. If a killed `liza init` left a lock behind, activation names it: remove it with `rmdir <path>`, then run `liza-activate`. If activation names copies of your files that an interrupted or failed activation left in the clone's git dir, compare each with its file, keep what you want, and move the copy out of its folder (`git rev-parse --git-path liza/originals`, or `git rev-parse --git-path liza/clone-versions` for `.bash-policy.yaml` and `.claudeignore`), then run `liza-activate`. If `liza-deactivate` names such a copy because the `<name>.pre-liza` beside its file differs from it, keep what you want, move the copy out of its folder, and run `liza-deactivate` again. To retry a step, run it from the workspace folder: `bash /usr/local/share/enchantments/liza/<hook>.sh`. If nothing was reported but it isn't set up, see `https://github.com/Jartan-LLC/enchantments/blob/main/docs/troubleshooting.md`. `liza-activate` reports at once, and exits non-zero when something failed.

## Removal

1. While the Feature is still declared, in each clone, run `liza-deactivate --tools` if `liza-toolchain` is declared, then `liza-deactivate`.
2. Remove the `liza` entry, and `liza-toolchain`'s if declared, from the project's config and from `defaultFeatures`.
3. Remove the container, then the volume: `docker volume rm liza-<devcontainerId>` (under Docker Compose, `<project>_liza-<devcontainerId>`).


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/Jartan-LLC/enchantments/blob/main/src/liza/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
