## Unreleased

- Creating the container no longer takes another user's files in the volume;
  it takes only root's, and warns of the other user's.
- The report of a failed `liza toolchain configure` names its likely cause and the fix.

### Minor

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
