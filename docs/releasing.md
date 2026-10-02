# Releasing

## How a release happens

On every run on main (push, the daily schedule or a manual dispatch), CI's `pending` job
asks the registry which ids' versions aren't on their `:1` tag yet, and checks each one's
changelog entry. When it lists any, `publish` waits for an approval of the `ghcr`
environment. It only runs when `check` passed and the full `test` matrix ran and passed in
that same run, so the tree it publishes is the one that run tested. A push that changes no
Feature skips `test`, and its pending version ships with the next run on main that runs
the full matrix: a push that runs it, the daily schedule, or a manual dispatch.

`publish` runs the pinned devcontainer CLI, which pushes each pending Feature (moving `:1`
only to a version higher than every published one) and prints a JSON line with each id's
published tags and digest. Afterwards, CI's `visibility` job checks that every id's
`:1` can be pulled without credentials.

## Before approving

- Each id `pending` lists had its version raised by a change merged since the last
  release. A failed registry lookup, an outage included, also lists already-published ids;
  reject the deployment then. Approving it anyway does no harm: the CLI skips a version
  that exists.
- Every merge to main touching `src/` since the last release was merged by you. No
  auto-merged PR can touch `src/`, so a `github-actions` merge of one means that rule
  failed.
- A new id: [the first-release checks](adding-a-feature.md#the-first-release).

## Versioning

Each Feature has its own semver, starting at `1.0.0`:

- a pin bump is minor;
- removing or renaming an option, or a change in behavior a consumer would notice, is
  major;
- anything else is a patch.

Once a Feature's `devcontainer-feature.json` is on main, any change in its `src/<id>/`
raises its `version` and adds that version's entry to its `CHANGELOG.md`, in the same
commit, moving any `## Unreleased` lines under it. CI's `versions` job fails otherwise, and
a lower or equal version fails too, so reverting a release needs a new, higher version. A
change to only the Feature's `README.md`, `NOTES.md` or `CHANGELOG.md` needs no bump: list
a docs change under `## Unreleased`, and bump only when it matters enough to publish on its
own.

`CHANGELOG.md` lists versions newest first, after an optional `## Unreleased`:

```markdown
## Unreleased

- A docs change waiting for the next release.

## 1.1.0

- What this version changes.
```

## Dependabot PRs under `src/`

Dependabot updates `src/liza-toolchain/npm/package-lock.json`, and auto-merge skips branches
under `src/`, so the PR waits, red on the version check. Push a commit onto its branch that
bumps `liza-toolchain` and adds the changelog entry, then merge it by hand.

## Updating pins

Each Feature's pins live in `src/<id>/pins.sh`, one `# pin <kind> <tool>` header per pin.
By hand, pick a release at least 7 days old, as Dependabot's cooldown does. Then bump the
Feature's version.

| Pin | Where | To update |
|---|---|---|
| `asset`: liza, ripgrep, codebase-memory-mcp, ast-grep, yq, rtk, mdq, uv | the tag, and each arch's asset name and sha256 | set the tag; check the asset names, which are templates (`{tag}`, and `{version}`, the tag without its `v`); hash each arch's asset |
| `tag-commit`: scip-search | the tag and its commit | set both; the commit is what the tag resolves to |
| `branch-commit`: stacklit, functional-clusters, mdtoc, bash-policy | the commit | a commit on the default branch |
| `hf-model`: semble's model | the revision and each file's sha256 | the model's revision, and every file's sha256 at it |
| `node` | the version and each arch's sha256 | the newest LTS, with digests from its `SHASUMS256.txt` |
| `go` | the version and each arch's sha256 | a stable release, from `go.dev/dl/?mode=json` |
| `uv-lock`: semble | `semble-requirements.txt`, from `semble.in` | the command in its header |
| npm tools (scip-python, scip-typescript, context7) | `src/liza-toolchain/npm/package-lock.json` | Dependabot, as above |
| The spec schema | the `--schemafile` URL in `.pre-commit-config.yaml` | a newer `devcontainers/spec` commit, when lint rejects a property the spec allows; no Feature bump |
| Liza | `liza` in `src/liza/pins.sh` | as an `asset`, plus the checks below |

A Liza release also needs, in the same PR, bumping both `liza` and `liza-toolchain`:

- `liza --help`'s global flags that take a value checked against the `case` at the top of
  `src/liza/shim.sh`;
- upstream `contracts/AGENT_TOOLS.md` diffed between the old and new tags, with the changes
  carried into `src/liza-toolchain/AGENT_TOOLS.md` and `src/liza/AGENT_TOOLS.minimal.md`.
  Keep the minimal file's graph rows as `rg`, and every rtk mention inside the `#### RTK`
  section (which ends at the next heading or `---`), except `rtk jq`: activation drops that
  section, and rewrites `rtk jq` as `jq`, where rtk can't run;
- `src/liza-toolchain/configure.args` checked against `liza toolchain configure --help`.

Liza's own `liza toolchain install` isn't used: it fetches unpinned installers.

## Scheduled runs

GitHub disables a public repo's scheduled workflows after 60 days with no activity; merged
Dependabot PRs normally prevent that. If `gh workflow list --all` shows `ci.yml` disabled,
re-enable it with `gh workflow enable ci.yml`.
