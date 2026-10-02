# A bad release

`defaultFeatures` consumers take whatever `:1` points at on their next build, so a bad
release spreads until it's contained.

## Contain

Clear `dev.containers.defaultFeatures`. For a compromised plugin marketplace, that isn't
enough: see [below](#a-marketplace-compromise).

## Recover

1. Revert the change, and bump to a version higher than the highest published `1.x.y`, not
   merely a patch above the reverted source. List them with
   `devcontainer features info tags ghcr.io/jartan-llc/enchantments/<id>:1`. The CLI moves
   `:1` only for a version higher than every published one.
2. Publish through the gated job, then confirm that
   `devcontainer features info manifest ghcr.io/jartan-llc/enchantments/<id>:1 --output-format json | jq -r .canonicalId`
   matches the same query for the new version.

**Never delete the bad version on GHCR before the fixed one is live and `:1` resolves to
it.** Until then, deleting it takes `:1`, `1.x` and `latest` with it, and breaks every
build that uses `defaultFeatures`.

## Declared consumers

Scaffold, enchantments, and every repo that declares these Features in its config: where
the committed `.devcontainer/devcontainer-lock.json` holds a bad digest, close any open
Dependabot PR to it. Once the fix is live, run `devcontainer upgrade --workspace-folder .`
and merge the change by hand, without waiting for the cooldown.

## A marketplace compromise

A bad commit on the default branch of a plugin marketplace you use isn't contained by
clearing `defaultFeatures`: a plugin hook runs as you and holds the gh token. Follow
[If it may have been malicious](#if-it-may-have-been-malicious) in full, step 1 first.
Then, from the clean host, revert grimoire's `main`, or for a marketplace you don't
control, commit and push the removal of its `extraKnownMarketplaces` entry and its
`@<name>` `enabledPlugins` keys from each affected repo's committed `.claude/settings.json`
before step 5; step 5's volume deletion and re-clone discard the user- and local-scope
declarations. Don't rely on the attach refresh. Then run step 2 (including the per-id GHCR
comparison), step 4 if any unapproved version exists, and step 5. Only step 3 depends on a
bad Feature version.

## If it may have been malicious

Any route other than a plain bug. A Feature's metadata can grant privileged mode and host
mounts, and these containers hold the host Docker socket, so treat the Docker host as
compromised throughout.

1. **Contain at once,** before any revert or publish. Stop every container that mounts
   `claude-data`, `gh-config` or a `liza-*` volume (`docker ps -a --filter
   volume=claude-data`, and likewise for the others), since the shared volume carries
   whatever the bad code planted. Don't start or attach to them again: their `postStart`
   and `postAttach` hooks re-run from the image metadata. From a clean host, or the GitHub
   web UI (Settings → Applications), revoke the gh token. Also revoke Claude sessions and
   any MCP keys at their issuers. Re-authenticate only on that clean host, which is enough
   to review and approve the fix.
2. **Audit GitHub for footholds** the token could have left.
   - In the Jartan-LLC audit log (web UI, owners only), review the exposure window and
     undo what it shows: deploy keys, collaborators and invites, webhooks, rulesets,
     environment edits, apps and membership, across every Jartan-LLC repo.
   - Review your account's security log for added SSH or GPG keys, OAuth authorizations
     and personal-repo events.
   - For scaffold (a template, so anything planted spreads), enchantments, grimoire and
     every repo that declares these Features, review default-branch commits and merged PRs
     in the window (`git log --since`,
     `gh pr list --state merged --search 'merged:>=<start>'`), and revert any you didn't
     make.
   - Check the `main` ruleset's content: this prints `true`.

     ```bash
     gh api repos/Jartan-LLC/enchantments/rulesets/$(gh api repos/Jartan-LLC/enchantments/rulesets --jq '.[] | select(.name=="main" and .source_type=="Repository") | .id') --jq '.enforcement=="active" and .bypass_actors==[] and .conditions.ref_name.include==["~DEFAULT_BRANCH"] and ([.rules[].type]|sort)==["deletion","non_fast_forward","pull_request","required_linear_history","required_status_checks"] and any(.rules[]; .type=="required_status_checks" and any(.parameters.required_status_checks[]; .context=="check" and .integration_id==15368))'
     ```

   - Check the `ghcr` environment's content: on the environment GET,
     `.deployment_branch_policy` equals
     `{"protected_branches":false,"custom_branch_policies":true}`; its branch policies
     equal `["main"]`; and
     `--jq '[.protection_rules[]|select(.type=="required_reviewers")|.reviewers[].reviewer.login]'`
     equals `["JartanFTW"]`. Check against these expected values, never against a peer
     repo the same token could have changed.
   - For every id, compare
     `gh api orgs/Jartan-LLC/packages/container/enchantments%2F<id>/versions` with the
     approved `publish` runs.
3. **Remediate:** do the [recovery](#recover) and the
   [declared-consumer step](#declared-consumers), then confirm that each consumer's
   lockfile on its remote no longer names any unapproved digest from step 2
   (`git grep <bad-digest> origin/main -- .devcontainer/devcontainer-lock.json` prints
   nothing for each). Key on digests, not version strings: a token holder can push a
   manifest to `:1` alone, or reuse an approved version string in its metadata.
4. **Delete every unapproved GHCR version,** once `:1` resolves to the fix.
   `gh auth refresh -s read:packages,delete:packages`; find each with
   `gh api orgs/Jartan-LLC/packages/container/enchantments%2F<id>/versions --jq '.[] | select(.name=="<bad-digest>") | .id'`
   for each unapproved digest, whatever its tags; delete it with
   `gh api -X DELETE .../versions/<version-id>`; then
   `gh auth refresh -r read:packages,delete:packages`. Confirm that each version is gone
   from that listing, that
   `devcontainer features info manifest ghcr.io/jartan-llc/enchantments/<id>:<bad-version>`
   fails where the bad release added a semver tag, and that `:1` still resolves to the fix.
   Past 5,000 downloads, only GitHub Support can remove a version.
5. **Rebuild clean:** remove every container step 1 stopped, then the `claude-data`,
   `gh-config` and all `liza-*` volumes, not only the dangling ones. Rebuild the Docker
   host, and rotate every credential it held or forwarded into containers, including
   MCP-server keys and tokens stored in `claude-data`. Re-clone workspaces from their
   remotes instead of reopening the old clones, because hooks may have planted
   `.git/config`, `.git/hooks` or `.devcontainer/` changes. Only then rebuild the
   containers and log in inside them again. Containers go first, so new credentials never
   land in a volume a compromised container still mounts.
