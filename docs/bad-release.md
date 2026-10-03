# A bad release

Every `defaultFeatures` container takes whatever `:1` points at on its next build, so act
fast.

## If it's a bug

1. **Contain it:** clear `dev.containers.defaultFeatures`.
2. **Fix it:** revert the change and give it a version higher than every published `1.x.y`
   (`devcontainer features info tags ghcr.io/jartan-llc/enchantments/<id>:1` lists them):
   `:1` moves only to a higher version. Release it, then check that
   `devcontainer features info manifest ghcr.io/jartan-llc/enchantments/<id>:1 --output-format json | jq -r .canonicalId`
   matches the same query for the new version.
3. **Fix the projects that declare it:** in each repo whose
   `.devcontainer/devcontainer-lock.json` holds the bad digest, enchantments included, close
   any open Dependabot PR to it, run `devcontainer upgrade --workspace-folder .`, and merge
   the result yourself.

Don't delete the bad version from GHCR before `:1` points at the fix: deleting it takes
`:1`, `1.x` and `latest` with it, and breaks every build that uses `defaultFeatures`.

## If a plugin marketplace is compromised

Clearing `defaultFeatures` doesn't stop a bad commit on a marketplace's default branch: its
plugins' hooks run as you, with your gh token. Do step 1 of
[If it may have been malicious](#if-it-may-have-been-malicious). Then, from the clean host,
revert the marketplace's default branch if you control it; otherwise remove its
`extraKnownMarketplaces` entry and its `@<name>` `enabledPlugins` keys from each affected
repo's `.claude/settings.json`, and push. Then do steps 2, 4 (if step 2 finds a version you
didn't approve) and 5.

## If it may have been malicious

Unless it's a plain bug, assume it was. A Feature can get root on the Docker host
([the trust boundary](trust-boundary.md)), so treat the host as compromised throughout.

1. **Contain at once,** before any revert or publish. Stop every container that mounts
   `claude-data`, `gh-config` or a `liza-*` volume (`docker ps -a --filter
   volume=claude-data`, and likewise for the others), since the shared volume carries
   whatever the bad code planted. Don't start or attach to them again: their `postStart`
   and `postAttach` hooks re-run from the image metadata. From a clean host, or the GitHub
   web UI (Settings → Applications), revoke the gh token. In the pin-bump App's settings,
   under Private keys, generate a new key, keep it on the clean host, and delete every
   older one: GitHub won't delete an App's only key. Also revoke Claude sessions and any
   MCP keys at their issuers. Re-authenticate only on that clean host, which is enough to
   review and approve the fix.
2. **Audit GitHub for footholds** the token could have left.
   - In the Jartan-LLC audit log (web UI, owners only), review the exposure window and
     undo what it shows: deploy keys, collaborators and invites, webhooks, rulesets,
     environment edits, apps and membership, across every Jartan-LLC repo.
   - Review your account's security log for added SSH or GPG keys, OAuth authorizations
     and personal-repo events.
   - For enchantments, every plugin marketplace you control, every template repo (anything
     planted there spreads to repos made from it) and every repo that declares these
     Features, review default-branch commits and merged PRs in the window
     (`git log --since`, `gh pr list --state merged --search 'merged:>=<start>'`), and
     revert any you didn't make.
   - Check the `main` ruleset's content: this prints `true`.

     ```bash
     gh api repos/Jartan-LLC/enchantments/rulesets/$(gh api repos/Jartan-LLC/enchantments/rulesets --jq '.[] | select(.name=="main" and .source_type=="Repository") | .id') --jq '.enforcement=="active" and .bypass_actors==[] and .conditions.ref_name.include==["~DEFAULT_BRANCH"] and ([.rules[].type]|sort)==["deletion","non_fast_forward","pull_request","required_linear_history","required_status_checks"] and any(.rules[]; .type=="required_status_checks" and any(.parameters.required_status_checks[]; .context=="check" and .integration_id==15368))'
     ```

   - Check the `ghcr` environment's content against these expected values, never against
     a peer repo the same token could have changed:

     ```bash
     env=repos/Jartan-LLC/enchantments/environments/ghcr
     gh api $env --jq .deployment_branch_policy
     # {"custom_branch_policies":true,"protected_branches":false}
     gh api $env/deployment-branch-policies --jq '[.branch_policies[].name]'
     # ["main"]
     gh api $env --jq '[.protection_rules[]|select(.type=="required_reviewers")|.reviewers[].reviewer.login]'
     # ["JartanFTW"]
     ```

   - Check that only main can use the `pin-bumps` environment:

     ```bash
     gh api repos/Jartan-LLC/enchantments/environments/pin-bumps/deployment-branch-policies --jq '[.branch_policies[].name]'
     # ["main"]
     ```

   - For every id, compare
     `gh api orgs/Jartan-LLC/packages/container/enchantments%2F<id>/versions` with the
     approved `publish` runs.
3. **Remediate:** do steps 2 and 3 of [If it's a bug](#if-its-a-bug), then confirm that
   each consumer's lockfile on its remote names no unapproved digest from step 2
   (`git grep <bad-digest> origin/main -- .devcontainer/devcontainer-lock.json` prints
   nothing for each). Key on digests, not version strings: a token holder can push a
   manifest to `:1` alone, or reuse an approved version string in its metadata.
4. **Delete every unapproved GHCR version,** once `:1` resolves to the fix.
   `gh auth refresh -s read:packages,delete:packages`; find each with
   `gh api orgs/Jartan-LLC/packages/container/enchantments%2F<id>/versions --jq '.[] | select(.name=="<bad-digest>") | .id'`
   for each unapproved digest, whatever its tags; delete it with
   `gh api -X DELETE orgs/Jartan-LLC/packages/container/enchantments%2F<id>/versions/<version-id>`;
   then
   `gh auth refresh -r read:packages,delete:packages`. Confirm that each version is gone
   from that listing, that
   `devcontainer features info manifest ghcr.io/jartan-llc/enchantments/<id>:<bad-version>`
   fails where the bad release added a semver tag, and that `:1` still resolves to the fix.
   Past 5,000 downloads, only GitHub Support can remove a version.
5. **Rebuild clean:**
   - Remove every container step 1 stopped, then the `claude-data`, `gh-config` and all
     `liza-*` volumes, not only the dangling ones.
   - Rebuild the Docker host, and rotate every credential it held or forwarded into
     containers, including MCP-server keys and tokens stored in `claude-data`.
   - From the clean host, replace the `pin-bumps` environment's `PIN_BUMPS_PRIVATE_KEY`
     secret with the key step 1 generated
     ([The pin-bump App](releasing.md#the-pin-bump-app)).
   - Re-clone workspaces from their remotes instead of reopening the old clones, because
     hooks may have planted `.git/config`, `.git/hooks` or `.devcontainer/` changes.
   - Only then rebuild the containers and log in inside them again. Containers go first,
     so new credentials never land in a volume a compromised container still mounts.
