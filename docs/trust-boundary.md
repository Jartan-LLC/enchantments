# The trust boundary

`defaultFeatures` applies to every container you open in VS Code, with no way to exclude a
repo. Each of those containers holds your Claude login, your user-wide `~/.claude` (hooks,
plugins, MCP servers) and your gh token, and the repo's own code (its setup, scripts and
tests) runs as the same user beside them. With `container-env`, that code can also change
the variables every other container's login shells export, `PATH` included.

## What a bad release can do

A Feature's metadata can ask for privileged mode and host mounts, and these containers hold
the host's Docker socket, so a bad `:1` gets root on the Docker host. `defaultFeatures`
isn't pinned by any lockfile: each build takes whatever `:1` points at. The release approval
and CI's tests catch broken releases; they don't stop someone who holds your gh token.

## How a bad release gets in

- **Your gh token.** It can push to enchantments and approve the `ghcr` deployment, so code
  running in any of these containers can publish a release that every other one runs as
  root at its next build.
- **The default branch of each enabled plugin's marketplace.** Each attach updates the
  clone's plugins from it, so whatever is merged there runs as you at the next attach,
  without a rebuild.
- **Write access to enchantments.** Any workflow on a branch can ask for permission to
  publish, and an admin can bypass or change the `ghcr` approval.
- **The pin-bump App's key.** It can push, and merge any change outside
  `.github/workflows/` once `check` passes, since main needs no approving review. Only
  main's runs can use it, through the `pin-bumps` environment, and a release still waits
  for your `ghcr` approval.
- **Auto-merged dependency bumps.** Minor and patch updates to what `publish` runs (the
  devcontainer CLI and the job's actions) merge automatically after Dependabot's 7-day
  wait, or at once for a security fix, and ship with the next release you approve.
- **Auto-merged releases in projects that declare these Features.** Their Dependabot
  updates merge automatically, so a project's lockfile only delays a bad release. To review
  each one instead, give `ghcr.io/jartan-llc/enchantments/*` its own Dependabot group and
  leave it out of auto-merge.
- **A name nobody has published.** A workflow in any Jartan-LLC repo can publish a package
  under that name first. [Adding a Feature](adding-a-feature.md) checks for this.

A container running as root also shares the volumes: what it writes to `claude-data` or
`gh-config` is owned by root, which a non-root container may fail to update until it's
recreated.

## Opening an untrusted repo

Clear `defaultFeatures` first; opening the repo outside a container gives its code your
whole host instead. Review its `.devcontainer/` too: any config can mount `claude-data`,
`container-env` and `gh-config` by name, and its `initializeCommand` runs on your host.

A fine-grained gh token, limited to the repos you work in, would narrow the first route.
