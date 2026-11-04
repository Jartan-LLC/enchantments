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
- In a UTF-8 locale, `liza-deactivate` could drop a line of yours from the
  clone's `.git/info/exclude` that isn't valid UTF-8, and in any locale it
  emptied that file if it held a NUL byte; it now keeps every line of yours.
  If you had such a line, check that the file still holds what you put there.
- No change in behavior: activation and `liza-deactivate` share one
  definition of the area activation lists before `liza init`, the top level
  and `.claude/`.
- `liza-deactivate` removed a `.claude/settings.local.json` that held `{}`
  before activation. It now removes one it empties only when activation
  created it. One that an earlier version's activation created in a repo that
  ignores it is left holding `{}`: delete it if you like.
- An activation interrupted while it swapped in your local settings for
  `liza init` could leave `.claude/settings.json` moved aside to
  `settings.json.liza-shim-held`, with or without your `settings.local.json`
  in its place, and the next activation refused until you moved them back.
  It now puts them back.
- With `~/.claude/CLAUDE.md` a file of your own, `liza init` links the
  repo-root `CLAUDE.md` to the contract when the clone has none, and
  activation also linked `CLAUDE.local.md` (or `.claude/CLAUDE.md`), so
  Claude loaded the contract twice. Activation now removes init's
  `CLAUDE.md` link, and activating again removes one an earlier version
  kept.
- A `liza init` that fails, such as on settings it can't merge, no longer
  leaves the contract linked at `~/.claude/CLAUDE.md` or the repo-root
  `CLAUDE.md`, where the next activation took the link for yours and kept
  it.

### Minor

- `liza`: v0.9.1 → v0.10.0
- When `CLAUDE.local.md` is your own file or symlink, activation links the
  contract at `.claude/CLAUDE.md` instead and leaves yours as it is. A file
  used to leave the contract unloaded, with a warning; a symlink was
  replaced with the contract link. When `.claude/CLAUDE.md` is taken too, by
  your own file or one the project commits, activation refuses and names
  both. To keep the contract at `CLAUDE.local.md`, move yours aside and run
  `liza-activate`; a clone whose symlink an earlier activation replaced
  keeps it there. Claude doesn't load `.claude/CLAUDE.md` in a worktree
  inside the clone, such as a multi-agent task's.
- With `.claude/skills` a symlink, activation wrote Liza's skill links in
  the folder it points to, replacing a link of yours there of the same name
  with no copy, and `liza-deactivate` left them; `liza init` wrote its hook
  scripts through a symlinked `.claude/hooks` the same way. Activation now
  refuses when `.claude`, `.claude/hooks` or `.claude/skills` is a symlink,
  until you make it a directory. If one of them was a symlink when you
  activated, remove Liza's skill links and hook scripts from the folder it
  points to.

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
