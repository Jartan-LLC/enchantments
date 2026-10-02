# The trust boundary

`defaultFeatures` is a user-level setting with no per-repo opt-out. While it's set, every
container you open in VS Code mounts your Claude login, a writable, user-wide `~/.claude`
(hooks, plugins, MCP entries) and your gh token. Any code in that repo runs as the same user
alongside them: its setup, package scripts and tests.

## What a bad release reaches

A Feature's metadata can declare privileged mode and host bind mounts, and these containers
hold the host Docker socket, so a bad `:1` reaches root on the Docker host. No lockfile pins
`defaultFeatures` consumers: they take whatever `:1` points at on their next build. The
release gate, the tests and the daily CI run stop broken releases, not someone holding your
gh token.

## The routes in

- **Your gh token.** With `repo` scope and admin rights on Jartan-LLC, code in any such
  container can push to enchantments and approve its own `ghcr` deployment, which every
  `defaultFeatures` container then runs as root at its next build.
- **Every enabled plugin's marketplace default branch,** grimoire's among them. The
  attach hook refreshes each plugin enabled for the clone, and its marketplace; `grimoire`
  follows a repo's committed ref, else the default branch. Whatever lands there, hooks
  included, runs as you at the next attach, with no rebuild, in every container that
  enables it. Anyone who can merge there can do this.
- **Write access to enchantments is publish access.** Any branch workflow can request
  `packages: write`, the `ghcr` environment gates only the `publish` job, and an admin can
  bypass or edit that gate.
- **Auto-merged bumps reach the publisher.** A minor or patch bump of anything that runs in
  `publish` (the devcontainer CLI, the actions the job uses) is auto-merged after Dependabot's
  7-day cooldown, and ships with the next approved release. Security updates skip the
  cooldown.
- **Auto-merged releases reach declared consumers.** Repos that declare these Features take
  minor and patch releases through Dependabot and auto-merge, so their lockfiles only delay
  a gh-token holder. To require a human merge, give `ghcr.io/jartan-llc/enchantments/*` its
  own Dependabot group before excluding it from auto-merge.
- **A not-yet-published name can be squatted** by a workflow in any Jartan-LLC repo. The
  first release of each id checks for this ([adding a Feature](adding-a-feature.md)).
- **A root container shares the volumes.** What it writes into `claude-data` or `gh-config`
  is root-owned, so a running non-root container can fail to rewrite those files until its
  next create repairs them.

## Opening an untrusted repo

Clear `defaultFeatures` first. Opening it outside a container instead would give its code
your host, which is less isolation, not more. That covers the repo's code, not its
`.devcontainer/`: any config can mount `claude-data` and `gh-config` by name, and
`initializeCommand` runs on the host, so review that directory before opening.

A narrower, fine-grained gh token would shrink the first route; it isn't set up.
