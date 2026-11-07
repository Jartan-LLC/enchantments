## 1.1.0

- On x86_64 and aarch64, when `plugins` lists any and no `node` is on `PATH`
  at build, a pinned, digest-checked Node is installed for the plugins' hooks.
  Only `node` goes on `PATH`, and last, so a Node from the image or a Feature
  is used instead. The install needs `curl` in the image.

## 1.0.2

- Plugins install when your user settings declare the grimoire marketplace
  with a github source other than the repo's, such as one without its pinned
  ref. The marketplace is then added from your source, with a warning.

## 1.0.1

- Claude runs without the hook's terminal, so plugin installs no longer stall.
- A failed step's report says why it failed.

## 1.0.0

- First release.
