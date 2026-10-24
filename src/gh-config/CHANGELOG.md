## Unreleased

- Creating the container no longer takes another user's files in
  `gh-config`, which locked that user's containers out of their login. It
  takes only root's, and each start warns of the other user's.
- A `gh` that isn't logged in is noted at each start, no longer reported as a
  failure.

### Minor

- Each start warns if `~/.config/gh` no longer links to `gh-config`, and makes
  files a root container left in it yours again where passwordless sudo is
  available, warning where it isn't.

## 1.0.0

- First release.
