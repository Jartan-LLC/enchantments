# Releasing

## Releasing a change

1. In the same commit as a change under `src/<id>/`, add its line under `## Unreleased`
   in the Feature's `CHANGELOG.md`, at its level ([Versioning](#versioning)), and leave
   its `version` alone. Merge the PR; the change waits there for the next release.
2. To release, merge the [release PR](#release-prs). CI's run on main then publishes each
   version that merge changed, which its `pending` job lists on its `Pending:` line.
3. While the `ghcr` environment has a required reviewer, the run waits in its `publish`
   job for your approval of the deployment. Before approving, check that the `Pending:`
   line lists the Features your release PR or a new Feature's PR released, and only
   those; for a new Feature, also do [Adding a Feature](adding-a-feature.md) step 7.
4. CI's `tag` job then tags each version it published ([Release tags](#release-tags)),
   and starts `pin-bumps.yml`, which rebuilds the release PR. CI's `visibility` job
   checks every Feature's `:1` can be pulled without credentials.

A run on main publishes only the versions its own push changed, from the commit it
tested, and only when its `check` and every Feature's tests passed, which a change under
`src/` always runs. Code merged after a release never ships under its version.

- **The daily run fails while a version on main isn't on GHCR,** naming it: while its
  release waits for your approval, during a GHCR outage, or after a publish that didn't
  happen, because it failed, you rejected it, or a newer run's replaced it while it
  waited. For the last, re-run that release's CI run, or withdraw the release.
- **To withdraw a release** before it's published, open a PR that returns the Feature's
  `version` to the published one and moves the release's entry back under
  `## Unreleased`, its minor and major lines under `### Minor` and `### Major` again. A
  `publish` still waiting for its approval would publish it: reject that first.
- **Publishing needs each published Feature's [release tag](#release-tags),** to list it
  in the collection; without one, a Feature whose main version is the published one comes
  from the commit that set that version. Otherwise every publish fails until you tag it.

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

Each Feature has its own version, which only the release PR raises, by the first level
that applies to any change it releases:

- **Major:** an option removed or renamed, or a change in behavior a project would notice.
- **Minor:** a new option, or a pin bump with a minor or larger upstream move.
- **Patch:** a pin bump whose upstream moves are all patches, or anything else.

Each change under `src/<id>/` adds its line under `## Unreleased` in the Feature's
changelog: a minor change's line under `### Minor`, a major one's under `### Major`; any
other line counts as a patch. A change to only the Feature's `README.md`, `NOTES.md` or
`CHANGELOG.md` needs no line; one listed there ships with the next release without
causing one.

```markdown
## Unreleased

- A fix.

### Minor

- A new option.

## 1.1.0

- What this version changes.
```

The release PR moves those lines into the new version's entry, leaving the subheadings
out. Only the PR that adds a Feature writes its version, `1.0.0`, and its `## 1.0.0`.
Reverting a change is a change too: it adds its own line.

CI's `versions` job fails a change to anything else under `src/<id>/` that adds no line
under `## Unreleased`. A version change must rise above GHCR's highest version, with its
entry and nothing left under `## Unreleased`, or return to that version; either way it
mustn't leave an entry for another version above GHCR's highest. A failed GHCR lookup
fails a version change.

## Dependabot PRs under `src/`

Dependabot's updates to a Feature's `npm/package.json` and `npm/package-lock.json` aren't
merged automatically. `dependabot-bumps.yml` finishes them hourly, and when you run
`gh workflow run dependabot-bumps.yml`: on each PR whose commits are all Dependabot's, it
pushes a commit listing the packages that moved under `## Unreleased`
([Versioning](#versioning)). Merge the PR once `check` passes; it ships with the next
release.

- **When Dependabot rebases the PR,** the commit goes, since its `[dependabot skip]` lets
  Dependabot push over it; the next run adds it again.
- **To change a PR,** push commits to its branch. Once it has a commit by anyone but
  Dependabot and the App, the workflow leaves it alone.
- **A PR that changes anything else under `src/`** fails the workflow's run, which names
  it, until you finish the PR by hand, adding its line under `## Unreleased`.

## Pin-bump PRs

`pin-bumps.yml` checks every `pins.sh` pin daily, after each change to `src/` on main, and
when you run `gh workflow run pin-bumps.yml`. For each Feature with a newer pin at least 7
days old, it opens one PR on the branch `pin-bumps/<id>`, which lists the bumps under
`## Unreleased` ([Versioning](#versioning)). A commit or other non-numeric pin, and a
requirement a lock adds or removes, count as a minor move, and an upstream major is still
a minor. Merge it once `check` passes; it ships with the next release. Nothing merges it
automatically.

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
  moves the bump's lines under `### Major`.
- **To change a PR,** push commits to its branch. Once the branch has a commit the
  workflow didn't make, the workflow stops updating it, and lists newer versions on a
  `Not applied:` line in the PR body instead. Once the PR merges, the next run proposes
  them in a new PR.
- **For a Liza bump,** commit the steps in [Updating pins](#updating-pins) to
  `pin-bumps/liza`, with a line for `liza-toolchain` under its `## Unreleased`; the PR
  has already listed `liza`'s.
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
since pushes and PRs made with a workflow's own token start no CI. To set it up, or to
replace it:

1. Create a GitHub App in Jartan-LLC with repository permissions **Contents: Read and
   write** and **Pull requests: Read and write**, and no webhook. Install it only on
   enchantments.
2. Create enchantments' `pin-bumps` environment, with its deployment branches limited to
   `main`. Set its variable `PIN_BUMPS_CLIENT_ID` to the App's Client ID, and its secret
   `PIN_BUMPS_PRIVATE_KEY` to a private key generated for the App, then delete the
   downloaded key.

To rotate the key, generate a new one, store it in `PIN_BUMPS_PRIVATE_KEY`, then delete
the downloaded file and the older keys. GitHub won't delete an App's only key.

## Release PRs

`pin-bumps.yml` also keeps one PR open on the branch `release`, as
[the pin-bump App](#the-pin-bump-app), titled with each version it releases. Merging it
publishes them, as in [Releasing a change](#releasing-a-change).

- **What it holds:** each Feature whose files, apart from `README.md`, `NOTES.md` and
  `CHANGELOG.md`, changed since its published version's
  [release tag](#release-tags). Its version is the published one raised by the largest
  level among its `## Unreleased` lines ([Versioning](#versioning)), and those lines
  become that version's entry.
- **What it leaves out:** a Feature whose version on main isn't the published one, as
  while its release is under way or waits for your approval, and one never published. A
  docs-only line waits under `## Unreleased` for the Feature's next release.
- **Each run** rebuilds the PR on main, unless `src/` on main hasn't moved since the PR's
  commit was built. To change a version or an entry, or to leave a Feature out, push a
  commit to `release`; the workflow then leaves the branch alone. Close the PR to have the
  next run rebuild it. With nothing left to release, the workflow closes the PR, unless a
  Feature failed that run.
- **A `pin-bumps: <id> release blocked` issue** means the PR leaves that Feature out:
  its GHCR lookup failed, its release tag is missing, or its files changed with no
  `## Unreleased` line. Fix the cause the issue quotes; the next run that doesn't fail on
  the Feature closes the issue.
- **A `pin-bumps: release push refused` issue** is the `release` branch's
  `push refused` issue ([Pin-bump PRs](#pin-bump-prs)): rebase it by hand, as the issue
  says.

## Updating pins

Each Feature's pins live in `src/<id>/pins.sh`, one `# pin <kind> <tool>` header per pin.
To update one by hand, pick a release at least 7 days old, then list the change as in
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

For a Liza release, in the same PR, add lines under `## Unreleased` for `liza-toolchain`,
and for `liza` too unless a pin-bump PR already has, and:

- check `liza --help`'s global flags that take a value against the `case` at the top of
  `src/liza/shim.sh`;
- diff upstream `contracts/AGENT_TOOLS.md` between the old and new tags, and carry the
  changes into `src/liza-toolchain/AGENT_TOOLS.md` and `src/liza/AGENT_TOOLS.minimal.md`.
  Keep the minimal file's graph rows as `rg`, and every rtk mention inside the
  `#### RTK` section (which ends at the next heading or `---`), except `rtk jq`: where
  rtk can't run, activation drops that section and rewrites `rtk jq` as `jq`;
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
disabled, run `gh workflow enable <file>`.
