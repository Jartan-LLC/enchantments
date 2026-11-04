## Unreleased

- Liza is activated only in a repo's main checkout. From a linked worktree,
  `liza init` wrote to the main checkout, its committed
  `.claude/settings.json` included, and activation then failed; container
  creation now skips a linked worktree with a note, and `liza-activate`
  refuses there. If activation ran in a linked worktree, run `git status` in
  the main checkout and undo what Liza changed there, such as
  `.claude/settings.json`.
- `liza -C <dir> init` protected `<dir>`'s files while Liza wrote to the
  clone you were in; it now refuses when `<dir>` is outside that clone. If
  you ran it with `-C` naming another clone, run `git status` in the clone
  you ran it in and undo what Liza changed there.
- Activation no longer needs git 2.36.
- Activation dropped `permissions.defaultMode` from
  `.claude/settings.local.json`, which left the mode from the project's
  `.claude/settings.json` or your `~/.claude/settings.json`, or else Claude
  Code's default, in effect. `liza init` removes it from the settings file it
  merges into, and activation hands it that file. Activation now puts it
  back, and says so after Liza's notice that it removed the mode. A clone
  an earlier version activated has already lost its mode, and activating it
  again doesn't bring it back: set it again in `.claude/settings.local.json`,
  where later activations and `liza-deactivate` keep it, or run
  `liza-deactivate`, which puts it back, then `liza-activate`.
- The `AGENT_TOOLS.md` that activation stages without the toolchain
  follows Liza v0.10.0's: search test sources before renaming a symbol or
  rewording a message, and, for Claude, how to run and wait for a long
  background command.

### Minor

- `liza`: v0.9.1 → v0.10.0
- Installs a pinned, digest-checked `pre-commit` when none is on `PATH`,
  since Liza v0.10.0's multi-agent `liza init` refuses without one. A
  `pre-commit` of yours on `PATH`, even one installed later, is used
  instead.
- When `CLAUDE.local.md` is your own file or symlink, activation links the
  contract at `.claude/CLAUDE.md` instead and leaves yours as it is. A file
  used to leave the contract unloaded, with a warning; a symlink was
  replaced with the contract link. When `.claude/CLAUDE.md` is taken too, by
  your own file or one the project commits, activation refuses and names
  both. To keep the contract at `CLAUDE.local.md`, move yours aside and run
  `liza-activate`; a clone whose symlink an earlier activation replaced
  keeps it there. Claude doesn't load `.claude/CLAUDE.md` in a worktree
  inside the clone, such as a multi-agent task's.

## 1.2.0

- Activation backs up ignored files only where it writes: the top level,
  `.claude/` itself, `.claude/hooks/` and the skill links in `.claude/skills/`.
  Ignored content elsewhere, such as a workspace folder, no longer slows it
  down; a workspace folder git shows is still backed up, so ignore it to skip
  it. An interrupted backup leaves no copies behind, unless it is killed
  outright.
- Copies a backup interrupted before this release left in
  `originals/`, in the folder `git rev-parse --git-path liza` prints
  (`.git/liza/` outside a linked worktree), may stay: in a clone with no
  `activation.json` in that folder, run `liza-deactivate`, compare each
  `<name>.pre-liza` it leaves with its file and keep what you want, then run
  `liza-activate`.
- Activation refuses while copies of your files that an interrupted activation
  left in the clone's git dir differ from those files, and names them all
  to move out; the empty folders left once they're out no longer stop another
  worktree from activating. Before, activating again replaced such a copy,
  which may be your only one, and then deleted it. A copy that matches its
  file doesn't stop it.
- `liza-deactivate` drops a copy in the clone's git dir that its record
  doesn't list when the copy matches its file, instead of putting it beside
  the file as `<name>.pre-liza`.
- After an interrupted `liza init`, the files put back are no longer reported
  as not restored, and their copies no longer stay in the clone's git dir.
- `liza-deactivate` no longer replaces a `<name>.pre-liza` already beside a
  file. When it differs from the copy deactivation would save there, the run
  fails and names the copy, which stays in the clone's git dir: keep what you
  want, move the copy out of its folder, and run `liza-deactivate` again.
- Activation keeps your edits to `.bash-policy.yaml` and `.claudeignore`,
  merged with what Liza changed since the last activation, where it used to
  replace them with Liza's version. Yours stays as it is, with Liza's version
  beside it as `<name>.liza`, when the two conflict, when the file is yours
  from before Liza, or when you edited it in a clone an earlier version
  activated. `liza-deactivate` keeps a merged file as one you've edited.
- A failed or interrupted `liza init` puts your `.bash-policy.yaml` and
  `.claudeignore` back. Activation refuses while a copy of either file that an
  interrupted or failed activation left in the clone's git dir differs from
  the file; `liza-deactivate` puts such a copy beside the file as
  `<name>.pre-liza`.

## 1.1.0

- Creating the container no longer re-owns files of another uid in the volume,
  such as your old uid after a rebuild under a new one. It warns with the
  command to take them, and takes nothing while they're there, root's files
  included.
- The report of a failed `liza toolchain configure` names its likely cause and the fix.
- Each start warns if `~/.liza` is missing or isn't the volume, or if
  `~/.local/bin/rg` is missing or doesn't run.

## 1.0.2

- Claude runs without the hook's terminal.
- The description names ripgrep.

## 1.0.1

- Downloads retry after any error, a reset connection included, where the image's curl
  is 7.71 or later.

## 1.0.0

- First release.
