## Unreleased

- Creating the container no longer takes another user's files in the volume,
  which locked that user's containers out of them. It takes only root's, and
  each start warns of the other user's.

### Minor

- Each start makes files a root container left in the volume yours again where
  passwordless sudo is available, and warns where it isn't.

## 1.1.0

- `direnv`: v2.37.1 → v2.38.2

## 1.0.0

- First release.
