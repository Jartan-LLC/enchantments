## Unreleased

- Creating the container no longer takes another user's files in
  `claude-data`, which locked that user's containers out of their login. It
  takes only root's, and each start warns of the other user's. A volume left
  with an old uid of yours warns too, with the command to take it.

### Minor

- Each start warns if `~/.claude` or `~/.claude.json` no longer links into
  `claude-data`, and makes files a root container left in it yours again
  where passwordless sudo is available, warning where it isn't.

## 1.0.1

- Claude runs without the hook's terminal, so the attach refresh no longer hangs.

## 1.0.0

- First release.
