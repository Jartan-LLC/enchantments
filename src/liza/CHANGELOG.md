## Unreleased

- Activation backs up ignored files only where `liza init` writes (the top
  level, `.claude/` itself and `.claude/hooks/`), so ignored content elsewhere,
  such as a workspace folder, no longer slows it down. An interrupted backup
  leaves no copies behind.
- Activation refuses when a copy of one of your files left by an interrupted
  `liza init` is in the way, and names the copy to move out of
  `.git/liza/originals/`. Running it again had replaced that copy, which may be
  your only one, and then deleted it.

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
