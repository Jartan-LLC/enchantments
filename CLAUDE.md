# enchantments

Dev container Features for Jartan LLC's projects, each one installable on its own.
Written in POSIX `sh` and bash.

## Rules

The project rules live in `GUARDRAILS.md`, ranked by how firmly each holds; this import
loads them into every session:

@GUARDRAILS.md

## Corrections

<!-- Version mismatches are the most common — fill these in early.
"We use Pydantic v2 field_validator, not v1 validator."
"Next.js 15 uses async cookies() — not the sync API from v14." -->

## Skills

<!-- Add project-specific skills and conventions here as they develop. -->

## Verify

Run `make check` before declaring work done — it runs lint and the strict docs build:

```bash
make check
```

A change under `src/`, `lib/` or `test/` is done only when the PR's `check` passes in CI.
Don't run `devcontainer features test` locally: it mounts and writes to your real
`claude-data` and `gh-config` volumes. `.github/scripts/test-features.sh` deletes
them, and `liza-rebuild`.

Individual targets (`make lint`, `make docs`) speed up the inner loop; `make help` lists
them.
