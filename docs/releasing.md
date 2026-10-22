# Releasing

## Releasing a change

1. In the same commit as the change, release it as [Versioning](#versioning) sets out:
   raise the Feature's `version` in its `devcontainer-feature.json` and add a
   `## <version>` entry to its `CHANGELOG.md`, or, while main's version is unpublished,
   add the change's line to that version's entry. Either way, move any lines from
   `## Unreleased` into the entry.
2. Merge the PR. CI's run on main then waits, in its `approve` job, for your approval of
   the `ghcr` deployment. The `pending` job's log lists the Features it publishes, on its
   `Pending:` line. Approve the newest run waiting: a newer run that publishes cancels an
   older one still waiting when it reaches approval, and an approved run that's
   publishing finishes before the next one starts.
3. Before approving, check that:
   - each Feature on the `Pending:` line had its version raised since the last release, or
     is being released for the first time. Otherwise the registry lookup failed: reject
     the deployment and retry later;
   - you merged every change to `src/` since the last release yourself;
   - for a Feature's first release, the checks in
     [Adding a Feature](adding-a-feature.md) step 7 pass.
4. Approve. CI's `tag` job then tags each version it published
   ([Release tags](#release-tags)), and its `visibility` job checks every Feature's `:1`
   can be pulled without credentials.

A run on main publishes only when it ran every Feature's tests. A merge that changes only
docs doesn't, so its pending version waits for the daily run, or for one you start with
`gh workflow run ci.yml`. Those runs also build this repo's dev container, and publish only
if their `Dev container` job passes.

## Release tags

Each published version has the git tag `feature_<id>_<version>` on the commit its release
built, the naming `devcontainers/action` uses. CI's `tag` job makes it after `publish`, so
`git diff feature_<id>_<a> feature_<id>_<b> -- src/<id>` shows what changed between two
published versions. A tag never moves or goes: the `feature-tags` ruleset blocks deleting
and updating `feature_*` tags, with no bypass.

- **The `tag` job fails with `likely cause: main's workflows changed`,** since neither the
  workflow's token nor yours without the `workflow` scope can tag, through the API, a
  commit whose `.github/workflows` differ from main's tip. Tag it by hand over SSH, at the
  commit the run built (its `GITHUB_SHA`, which the run's summary shows):

  ```bash
  git tag feature_<id>_<version> <commit>
  git push origin feature_<id>_<version>
  ```

- **The `pending` job warns `<tag> is on GHCR but has no tag`** when a tag job missed one.
  Tag it by hand as above, at the commit of the run that published it: the one whose
  `Pending:` line lists the id and whose `publish` succeeded.
- **To recreate the ruleset,** for instance after it was changed in an incident:

  ```bash
  gh api repos/Jartan-LLC/enchantments/rulesets --input - <<'EOF'
  {"name": "feature-tags", "target": "tag", "enforcement": "active",
   "conditions": {"ref_name": {"include": ["refs/tags/feature_*"], "exclude": []}},
   "rules": [{"type": "deletion"}, {"type": "non_fast_forward"}, {"type": "update"}]}
  EOF
  ```

## Versioning

Each Feature has its own version; raise the first level that applies:

- **Major:** an option removed or renamed, or a change in behavior a project would notice.
- **Minor:** a new option, or a pin bump with a minor or larger upstream move.
- **Patch:** a pin bump whose upstream moves are all patches, or anything else.

The level counts from the Feature's published version, not main's. While main's version
is unpublished, merged but not yet approved, a change rides it when the level's raise of
the published version is no higher: add the change's line to that version's entry and keep
the version. A change that needs a higher version renames the unpublished entry to the new
version and adds its line there, so no entry names a version that never shipped. With
1.1.1 published and main at 1.4.0, a minor change rides 1.4.0, and a major one makes 2.0.0
from the `## 1.4.0` entry. Once 1.4.0 is published, the next change raises it.

A change to a Feature's `README.md`, `NOTES.md` or `CHANGELOG.md` alone needs no new version:
list it under `## Unreleased` in the changelog, and it ships with the next release. CI's
`versions` job, which asks GHCR what's published, fails a change to anything else under
`src/<id>/` that doesn't do one of those: a raise without its entry, an entry left behind
for a version never published, or a ride whose version is published or whose lookup
failed, which then needs a raise. Reverting a release also needs a higher version.

- **A PR that rides a version you then approve** goes stale: its check passed before the
  version was published. Before merging it, re-run its CI, whose `versions` job then asks
  for a raise. The bots' PRs are rebuilt on their next run.

```markdown
## Unreleased

- A docs change that ships with the next release.

## 1.1.0

- What this version changes.
```

## Dependabot PRs under `src/`

Dependabot's updates to a Feature's `npm/package.json` and `npm/package-lock.json` aren't
merged automatically. `dependabot-bumps.yml` finishes them hourly, and when you run
`gh workflow run dependabot-bumps.yml`: on each PR whose commits are all Dependabot's, it
pushes a commit releasing the update as [Versioning](#versioning) sets out, with changelog
lines listing the packages that moved. Merge the PR once `check` passes, as in
[Releasing a change](#releasing-a-change).

- **When Dependabot rebases the PR,** the commit goes, since its `[dependabot skip]` lets
  Dependabot push over it; the next run adds it again.
- **When the version a PR was finished as is published,** the next run replaces its commit
  with one raising the version above it.
- **To change a PR,** push commits to its branch. Once it has a commit by anyone but
  Dependabot and the App, the workflow leaves it alone.
- **A PR that changes anything else under `src/`** fails the workflow's run, which names
  it, until you finish the PR by hand: raise the version and add the entry yourself.

## Pin-bump PRs

`pin-bumps.yml` checks every `pins.sh` pin daily, after each change to `src/` on main, and
when you run `gh workflow run pin-bumps.yml`. For each Feature with a newer pin at least 7
days old, it opens one PR on the branch `pin-bumps/<id>`, which releases the bumps as
[Versioning](#versioning) sets out; the first run after you publish the version it rides
rebuilds it above that version. A commit or other non-numeric pin, and a requirement a
lock adds or removes, count as a minor move, and an upstream major is still a minor.
Merge it as in [Releasing a change](#releasing-a-change); nothing merges it automatically.

- **To skip a version,** close the PR unmerged. Its versions go on the next PR's
  `Excluded:` list, and newer versions are still proposed.
- **To allow a skipped version again,** delete it from the `Excluded:` line of the
  Feature's most recent pin-bump PR, open or closed. If that PR was closed unmerged, also
  delete it from the `<!-- pin-bumps held: … -->` comment in the PR's body, which shows
  when you edit the body.
- **A PR the workflow closes,** with `Closed: nothing newer.` in its body, had nothing
  left to propose. Unlike your close, it excludes nothing.
- **For an upstream major,** which the PR body names, check whether the Feature itself
  changed as [Versioning](#versioning)'s Major describes. If it did, push a commit that
  raises the Feature's major version and renames its changelog entry to match.
- **To change a PR,** push commits to its branch. Once the branch has a commit the
  workflow didn't make, the workflow stops updating it, and lists newer versions on a
  `Not applied:` line in the PR body instead. Once the PR merges, the next run proposes
  them in a new PR.
- **For a Liza bump,** commit the steps in [Updating pins](#updating-pins) to
  `pin-bumps/liza`, with `liza-toolchain`'s version raise and changelog entry; the PR has
  already raised `liza`'s. If a `pin-bumps/liza-toolchain` PR merges first, check
  `liza-toolchain`'s version and entry on `pin-bumps/liza` against main's again.
- **A `pin-bumps: <tool> lookup failing` issue** means a run couldn't look that pin up.
  Fix the cause the issue quotes, or wait out an upstream outage; the next run that looks
  it up closes the issue. A PR that changes the pin or its lookup runs it in CI's
  `pin-lookups` job. If the `node` lookup says a release `doesn't match its signature`
  or `is signed by a revoked release key`, leave the pins as they are; the issue closes
  once a newer release verifies. If it says `isn't signed by a pinned release key`,
  update Node's release keys ([Updating pins](#updating-pins)).
- **A `pin-bumps: <id> pin headers invalid` issue** means that Feature's `pins.sh` has
  a malformed `# pin` header, or none, so every run fails. Fix it; the next run closes
  the issue.
- **A `pin-bumps: <id> push refused` issue** means a run couldn't push the branch,
  usually because main has `.github/workflows/` changes, which the workflow's App can't
  push. Rebase the branch by hand, as the issue says. The next run that pushes the
  branch, or finds nothing to push, closes the issue.
- **An issue for a Feature or pin since removed** stays open, since no run reports on
  it again. Close it by hand.

### The pin-bump App

`pin-bumps.yml` and `dependabot-bumps.yml` push, and the first opens PRs, as a GitHub App,
since pushes and PRs made with a workflow's own token start no CI. To set it up, or to replace it:

1. Create a GitHub App in Jartan-LLC with repository permissions **Contents: Read and
   write** and **Pull requests: Read and write**, and no webhook. Install it only on
   enchantments.
2. Create enchantments' `pin-bumps` environment, with its deployment branches limited to
   `main`. Set its variable `PIN_BUMPS_CLIENT_ID` to the App's Client ID, and its secret
   `PIN_BUMPS_PRIVATE_KEY` to a private key generated for the App, then delete the
   downloaded key.

To rotate the key, generate a new one, store it in `PIN_BUMPS_PRIVATE_KEY`, then delete
the downloaded file and the older keys. GitHub won't delete an App's only key.

## Updating pins

Each Feature's pins live in `src/<id>/pins.sh`, one `# pin <kind> <tool>` header per pin.
To update one by hand, pick a release at least 7 days old, then release the change as in
[Releasing a change](#releasing-a-change).

| Pin | Where | To update |
|---|---|---|
| `asset`: liza, ripgrep, codebase-memory-mcp, ast-grep, yq, rtk, mdq, uv, direnv | the tag, and each arch's asset name and sha256 | set the tag; check the asset names, which are templates (`{tag}`, and `{version}`, the tag without its `v`); hash each arch's asset |
| `tag-commit`: scip-search | the tag and its commit | set both; the commit is what the tag resolves to |
| `branch-commit`: stacklit, functional-clusters, mdtoc, bash-policy | the commit | a commit on the default branch |
| `hf-model`: semble's model | the revision and each file's sha256 | the model's revision, and every file's sha256 at it |
| `node` | the version and each arch's sha256 | the newest LTS, with digests from its `SHASUMS256.txt`, signed by one of Node's release keys |
| Node's release keys | `NODE_KEYS_COMMIT` and `NODE_KEYS_SUM` in `.github/scripts/pin_lookups.sh` | the steps below; no Feature version |
| `go` | the version and each arch's sha256 | a stable release, from `go.dev/dl/?mode=json` |
| `uv-lock`: semble | `semble-requirements.txt`, from `semble.in` | run the command in its header, then restore the header lines uv replaces |
| npm tools (scip-python, scip-typescript, context7) | `src/liza-toolchain/npm/package-lock.json` | Dependabot, as above |
| The spec schema | the `--schemafile` URL in `.pre-commit-config.yaml` | a newer `devcontainers/spec` commit, when lint rejects a property the spec allows; no Feature version |
| Liza | `liza` in `src/liza/pins.sh` | as an `asset`, plus the steps below |

For a Liza release, in the same PR, raise `liza-toolchain`'s version, and `liza`'s unless
a pin-bump PR already has, and:

- check `liza --help`'s global flags that take a value against the `case` at the top of
  `src/liza/shim.sh`;
- diff upstream `contracts/AGENT_TOOLS.md` between the old and new tags, and carry the changes
  into `src/liza-toolchain/AGENT_TOOLS.md` and `src/liza/AGENT_TOOLS.minimal.md`. Keep the
  minimal file's graph rows as `rg`, and every rtk mention inside the `#### RTK` section
  (which ends at the next heading or `---`), except `rtk jq`: where rtk can't run,
  activation drops that section and rewrites `rtk jq` as `jq`;
- check `src/liza-toolchain/configure.args` against `liza toolchain configure --help`.

Liza's own `liza toolchain install` isn't used: it fetches unpinned installers.

When the `node` lookup says a release `isn't signed by a pinned release key`, update
Node's release keys:

1. Download `gpg-only-active-keys/pubring.kbx` at the newest `nodejs/release-keys` commit,
   and that release's `SHASUMS256.txt` and `SHASUMS256.txt.sig`.
2. Run `gpg --no-default-keyring --keyring ./pubring.kbx --verify SHASUMS256.txt.sig
   SHASUMS256.txt`. Check that it prints `Good signature`, and a `Primary key fingerprint`
   listed under Release keys in `nodejs/node`'s README.
3. Set `NODE_KEYS_COMMIT` to that commit and `NODE_KEYS_SUM` to the keyring's sha256.

## A disabled schedule

GitHub disables a public repo's scheduled workflows after 60 days without activity. If
`gh workflow list --all` shows `ci.yml`, `pin-bumps.yml` or `dependabot-bumps.yml`
disabled, run
`gh workflow enable <file>`.
