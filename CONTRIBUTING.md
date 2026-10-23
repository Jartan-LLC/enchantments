# Contributing

## Setup

```bash
uv venv        # skip in the devcontainer or with an environment already active
make install
```

`make install` installs the lint and docs tools and the pinned devcontainer CLI, and wires
the pre-commit hook; rerun it after dependencies change.

Requires Python 3.12+, [uv](https://docs.astral.sh/uv/getting-started/installation/) and
Node.js: `make install` installs the pinned devcontainer CLI, and `make docs` runs it.
`make test` also needs gpg.
`make lint` runs the [pre-commit](https://pre-commit.com/) hooks; some need
Docker (actionlint, lychee) and Node (markdownlint) — the devcontainer has both.

## Changing a Feature

- The shell helpers live in `lib/`, and each Feature carries copies of the ones it uses: edit
  `lib/`, then run `make vendor`. A Feature that starts using a helper gets its copy once,
  with `cp lib/<helper>.sh src/<id>/`.
- Each Feature's `README.md` is generated from its `devcontainer-feature.json` and `NOTES.md`:
  edit those, never `README.md`, then run `make readmes` and commit the result.
- A change under `src/<id>/` adds a line under `## Unreleased` in its `CHANGELOG.md`
  and leaves the version alone; a change to only its `README.md`, `NOTES.md` or
  `CHANGELOG.md` needs none. Follow the version rule in `GUARDRAILS.md`.
- Guides: [Adding a Feature](docs/adding-a-feature.md) ·
  [Releasing](docs/releasing.md) · [A bad release](docs/bad-release.md).

## Verify before opening a PR

```bash
make check
```

Runs lint, the docs build and the CI scripts' tests. A change under `src/`, `lib/` or
`test/` is done only when the PR's `check` passes in CI. Don't run
`devcontainer features test` locally: it writes to your real `claude-data`,
`container-env`, `gh-config` and `liza-<devcontainerId>` volumes.

## Conventions

- A Feature added, renamed or removed, or a change to what `README.md` or `docs/` tell
  consumers to do, adds a line to the root `CHANGELOG.md` under the current month's
  `## YYYY-MM` heading (add it if it's missing); a change to how the repository releases
  goes under that month's `### Maintenance`. CI fails a PR that adds or removes a Feature
  without a line naming it; a rename names both ids.
- Commits follow [Conventional Commits](https://www.conventionalcommits.org/)
  (`feat:`, `fix:`, `docs:`, `refactor:`, `chore:`).
- Report security issues privately via [SECURITY.md](.github/SECURITY.md), not a public issue.
