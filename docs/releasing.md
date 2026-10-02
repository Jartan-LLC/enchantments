# Releasing

## Releasing a change

1. In the same commit as the change, raise the Feature's `version` in its
   `devcontainer-feature.json` (see [Versioning](#versioning)) and add a `## <version>` entry
   to its `CHANGELOG.md`, moving any lines from `## Unreleased` into it.
2. Merge the PR. CI's run on main then waits for your approval of the `ghcr` deployment.
   The `pending` job's log lists the Features it publishes, on its `Pending:` line.
3. Before approving, check that:
   - each Feature on the `Pending:` line had its version raised since the last release, or
     is being released for the first time. Otherwise the registry lookup failed: reject
     the deployment and retry later;
   - you merged every change to `src/` since the last release yourself;
   - for a Feature's first release, the checks in
     [Adding a Feature](adding-a-feature.md) step 7 pass.
4. Approve. CI's `visibility` job then checks every Feature's `:1` can be pulled without
   credentials.

A run on main publishes only when it ran every Feature's tests. A merge that changes only
docs doesn't, so its pending version waits for the daily run, or for one you start with
`gh workflow run ci.yml`.

## Versioning

Each Feature has its own version:

- **Major:** an option removed or renamed, or a change in behavior a project would notice.
- **Minor:** a pin bump, or a new option.
- **Patch:** anything else.

A change to a Feature's `README.md`, `NOTES.md` or `CHANGELOG.md` alone needs no new version:
list it under `## Unreleased` in the changelog, and it ships with the next release. CI's
`versions` job fails a change to anything else under `src/<id>/` that doesn't raise the
version and add its entry. Reverting a release also needs a higher version.

```markdown
## Unreleased

- A docs change that ships with the next release.

## 1.1.0

- What this version changes.
```

## Dependabot PRs under `src/`

Dependabot's updates to `src/liza-toolchain/npm/package-lock.json` aren't merged
automatically, and fail the version check. Push a commit to the PR's branch that raises
`liza-toolchain`'s version and adds its entry, then merge it.

## Updating pins

Each Feature's pins live in `src/<id>/pins.sh`, one `# pin <kind> <tool>` header per pin.
Pick a release at least 7 days old, then release the change as above.

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
| The spec schema | the `--schemafile` URL in `.pre-commit-config.yaml` | a newer `devcontainers/spec` commit, when lint rejects a property the spec allows; no Feature version |
| Liza | `liza` in `src/liza/pins.sh` | as an `asset`, plus the steps below |

For a Liza release, in the same PR, raise the versions of both `liza` and `liza-toolchain`,
and:

- check `liza --help`'s global flags that take a value against the `case` at the top of
  `src/liza/shim.sh`;
- diff upstream `contracts/AGENT_TOOLS.md` between the old and new tags, and carry the changes
  into `src/liza-toolchain/AGENT_TOOLS.md` and `src/liza/AGENT_TOOLS.minimal.md`. Keep the
  minimal file's graph rows as `rg`, and every rtk mention inside the `#### RTK` section
  (which ends at the next heading or `---`), except `rtk jq`: where rtk can't run,
  activation drops that section and rewrites `rtk jq` as `jq`;
- check `src/liza-toolchain/configure.args` against `liza toolchain configure --help`.

Liza's own `liza toolchain install` isn't used: it fetches unpinned installers.

## A disabled schedule

GitHub disables a public repo's scheduled workflows after 60 days without activity. If
`gh workflow list --all` shows `ci.yml` disabled, run `gh workflow enable ci.yml`.
