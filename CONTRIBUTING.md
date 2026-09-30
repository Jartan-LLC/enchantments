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
`make lint` runs the [pre-commit](https://pre-commit.com/) hooks; some need
Docker (actionlint, lychee) and Node (markdownlint) — the devcontainer has both.

## Verify before opening a PR

```bash
make check
```

Runs lint and the docs build. A change under `src/`, `lib/` or `test/` is done only when
the PR's `check` passes in CI, which also runs the Feature tests. Don't run
`devcontainer features test` locally: it mounts and writes to your real `claude-data` and
`gh-config` volumes.

## Conventions

- Commits follow [Conventional Commits](https://www.conventionalcommits.org/)
  (`feat:`, `fix:`, `docs:`, `refactor:`, `chore:`).
- Report security issues privately via [SECURITY.md](.github/SECURITY.md), not a public issue.
