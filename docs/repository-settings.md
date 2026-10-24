# Repository settings

The GitHub settings CI relies on, with the values to recreate each one.
[A bad release](bad-release.md)'s audit checks repeat those values, so a change to one of
them updates both pages.

## The pin-bump App

`enchantments-pinkeeper`, a GitHub App in Jartan-LLC, installed only on enchantments,
with repository permissions **Contents: Read and write** and **Pull requests: Read and
write**, and no webhook. `pin-bumps.yml` and `dependabot-bumps.yml` push as it, and the
first opens PRs as it, since pushes and PRs made with a workflow's own token start no CI.
Its Client ID and a private key are in the
[`pin-bumps` environment](#the-pin-bumps-environment).

- **To rotate its key,** generate a new one in the App's settings, store it in
  `PIN_BUMPS_PRIVATE_KEY`, then delete the downloaded file and the older keys. GitHub
  won't delete an App's only key.
- **To replace it,** create a GitHub App in Jartan-LLC with the permissions above and no
  webhook, and install it only on enchantments. Set the
  [`pin-bumps` environment](#the-pin-bumps-environment)'s variable `PIN_BUMPS_CLIENT_ID`
  to its Client ID, and its secret `PIN_BUMPS_PRIVATE_KEY` to a private key generated for
  it, then delete the downloaded key.

## The `pin-bumps` environment

The environment of `pin-bumps.yml`'s and `dependabot-bumps.yml`'s jobs, holding the
App's credentials: the variable `PIN_BUMPS_CLIENT_ID` and the secret
`PIN_BUMPS_PRIVATE_KEY`. Its deployment branches are limited to `main`, so a workflow on
any other branch can't act as the App.

## The `ghcr` environment

The environment of CI's `publish` job. Its deployment branches are limited to `main`, and
it has the required reviewer `JartanFTW`, so each release waits for that approval
([Releasing a change](releasing.md#releasing-a-change)). A repository admin can bypass it.

## The `main` ruleset

Active on the default branch, with no bypass. It blocks deleting the branch and force
pushes, and requires a pull request, with no approving review, linear history, and the
`check` status from GitHub Actions (integration ID 15368). So a change reaches main, and
with it a release, only through a PR whose `check` passed; GitHub's auto-merge of
Dependabot bumps waits for it too.

## The `feature-tags` ruleset

Blocks deleting and updating `feature_*` tags, with no bypass, so a
[release tag](releasing.md#release-tags) never moves or goes. To recreate it, for instance
after it was changed in an incident:

```bash
gh api repos/Jartan-LLC/enchantments/rulesets --input - <<'EOF'
{"name": "feature-tags", "target": "tag", "enforcement": "active",
 "conditions": {"ref_name": {"include": ["refs/tags/feature_*"], "exclude": []}},
 "rules": [{"type": "deletion"}, {"type": "non_fast_forward"}, {"type": "update"}]}
EOF
```
