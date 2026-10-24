## Unreleased

- A `gh` that isn't logged in is noted at each start, no longer reported as a
  failure.

### Minor

- Each start warns if `~/.config/gh` no longer links to `gh-config`, and takes
  back files in it you don't own where passwordless sudo is available, warning
  where it isn't.

## 1.0.0

- First release.
