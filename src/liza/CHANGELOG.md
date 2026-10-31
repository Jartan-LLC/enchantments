## Unreleased

- Activation backs up ignored files only where it writes: the top level,
  `.claude/` itself, `.claude/hooks/` and the skill links in `.claude/skills/`.
  Ignored content elsewhere, such as a workspace folder, no longer slows it
  down. An interrupted backup leaves no copies behind, unless it is killed
  outright. Copies left by a backup interrupted before this release may stay:
  in a clone with no `.git/liza/activation.json`, remove
  `.git/liza/originals/` before running `liza-activate` or `liza-deactivate`.
- Activation refuses while copies of your files that an interrupted activation
  left in `.git/liza/originals/` differ from those files, and names them all
  to move out. Running it again had replaced such a copy, which may be your
  only one, and then deleted it. A copy that matches its file doesn't stop
  it.
- After an interrupted `liza init`, the files put back are no longer reported
  as not restored, and their copies no longer stay in `.git/liza/originals/`.

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
