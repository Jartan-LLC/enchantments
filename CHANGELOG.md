# Changelog

Changes to the collection as a whole: Features added, renamed or removed, and
changes to what the docs tell you to do with the Features. What a Feature installs,
version by version, is in its own `src/<id>/CHANGELOG.md`. Maintenance lists
changes to how this repository releases, for its maintainers.

Sections are months, newest first.

## 2026-11

- `liza`: activation keeps its record and copies in the clone's git dir, in
  the folder `git rev-parse --git-path liza` prints (`.git/liza/` outside a
  linked worktree). When activation names copies of your files that an
  interrupted activation left in `originals/` there, compare each with its
  file, keep what you want and move the copy out of that folder, then run
  `liza-activate`. In a clone where an interrupted activation left
  `originals/` but no `activation.json`, run `liza-deactivate` instead,
  compare each `<name>.pre-liza` it leaves with its file and keep what you
  want, then run `liza-activate`.

## 2026-10

- The first Features, each declared as `ghcr.io/jartan-llc/enchantments/<id>:1`:
  - `claude-code`: Claude Code, self-updating, with its login kept across rebuilds.
  - `codebase-memory-mcp`: a code graph Claude Code can query.
  - `gh-config`: the GitHub CLI's login, kept across rebuilds (`gh` not included).
  - `grimoire`: Claude Code plugins from the grimoire marketplace.
  - `liza`: Liza, rules and a multi-agent workflow for coding agents, with ripgrep.
  - `liza-toolchain`: Liza's agent tools, such as code indexes and code search.
  - `container-env`: per-device environment variables, kept out of every repo.
- `stripe-cli`, a new Feature: the Stripe CLI from a pinned release.
- Each Feature's page follows the same order of sections and ends with how to remove
  it, including what it leaves behind, such as a volume.
- Every Feature installs only on a Debian-based image (Ubuntu included) with
  bash; on any other it installs nothing, with a warning, and the container
  still builds.
- `claude-code`, `container-env`, `gh-config`, `liza` and `liza-toolchain` check
  their setup each time the container starts and warn of what's wrong, such as
  a volume no longer linked, so a project needn't check those Features'
  internals itself.
- Containers that share a Feature volume must run as one uid. A container
  running as another uid warns instead of taking the volume, as it used to,
  locking the others out of their logins.

### Maintenance

- A change to a Feature's files, other than its `README.md`, `NOTES.md` or
  `CHANGELOG.md`, lists itself under `## Unreleased` in the Feature's changelog
  and leaves its version alone. `pin-bumps.yml` keeps one release PR open that
  raises each changed Feature's version and moves its lines into that
  version's entry (#62, #63).
- A push that brings a version not yet on GHCR publishes it from that push's
  tested commit once a maintainer approves the `ghcr` deployment; a newer run's
  publish may replace one still waiting (#10, #55, #63). Scheduled and manual
  runs fail while a version on main isn't on GHCR (#63).
- Each published version is tagged `feature_<id>_<version>` at the commit it
  was built from (#57).
- pin-bumps proposes upstream pins at least 7 days old as one PR per Feature
  (#13). Dependabot's PRs under `src/` get their `## Unreleased` line pushed by
  the pin-bump App (#53).
- A Feature's major version now means a change that breaks a working setup, and
  its minor version covers new behavior that keeps working setups working, not
  only a new option or a pin bump.
