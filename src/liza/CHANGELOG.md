## Unreleased

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
- Activation keeps your edits to `.bash-policy.yaml` and `.claudeignore`,
  merged with what Liza changed since the last activation, where it used to
  replace them with Liza's version. Yours stays as it is, with Liza's version
  beside it as `<name>.liza`, when the two conflict, when the file is yours
  from before Liza, or when you edited it in a clone an earlier version
  activated. A failed or interrupted `liza init` puts your version back, and
  `liza-deactivate` keeps a merged file as one you've edited. Activation
  refuses while a copy of either file that an interrupted or failed activation
  left in the clone's git dir differs from the file; `liza-deactivate` puts
  such a copy beside the file as `<name>.pre-liza`.

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
