## Unreleased

- Plugins install when your user settings declare the grimoire marketplace
  with a github source other than the repo's, such as one without the repo's
  pinned ref: the marketplace is added from your entry's source, and the hook
  warns that the repo's isn't used.

## 1.0.1

- Claude runs without the hook's terminal, so plugin installs no longer stall.
- A failed step's report says why it failed.

## 1.0.0

- First release.
