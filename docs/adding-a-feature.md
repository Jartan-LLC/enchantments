# Adding a Feature

1. **Create `src/<id>/`** with `devcontainer-feature.json` at `"version": "1.0.0"`,
   `install.sh` and the payload, a `NOTES.md` in the order `CONTRIBUTING.md` gives
   (Changing a Feature), and a `CHANGELOG.md` whose only entry is `## 1.0.0`. In
   `NOTES.md` and `CHANGELOG.md`, write links as absolute GitHub URLs or code spans.
2. **Add its tests** in `test/<id>/`, and add the id to the `alpine`, `javascript-node` and
   `root-user` scenarios in `test/_global/scenarios.json`. If it mounts a volume, add the
   name its test scenarios mount to `volumes` in `.github/scripts/test-features.sh`.
3. **Pin what it downloads.** For an npm lockfile, add a `dependabot.yml` block; for anything
   else, add a `pins.sh` entry of one of the kinds in [Updating pins](releasing.md#updating-pins).
   Either way, add a row to that table saying how to update it.
4. **Document it:** copy a sibling's `docs/features/<id>.md` and add it to the Features
   toctree in `docs/index.md`, add a row to the Feature list in the root `README.md`, add
   it to [Choosing Features](choosing.md), and add a line for it to the root
   `CHANGELOG.md`. If it mounts a volume, add its row to [What persists](persistence.md)
   and its name to the `docker volume ls` filter in [A bad release](bad-release.md)'s
   step 1.
5. **Run `make readmes`** and commit the generated `src/<id>/README.md`, then `make check`.
6. **Open the PR.** It needs a green `check`.
7. **Publish it.** Before merging, run `gh auth refresh -s read:packages`, then check
   that `gh api orgs/Jartan-LLC/packages/container/enchantments%2F<id>` returns 404.
   Anything else, 403 included, fails the check: don't merge. A package linked to this
   repo proves nothing: GHCR links whatever repo the package's source label names. Then
   merge: the merge's CI run publishes the Feature. When it waits for your approval of
   the `ghcr` deployment, check that the id is on the `Pending:` line of its `pending`
   job log, and run the 404 check again.

   After the release, check that
   `gh api orgs/Jartan-LLC/packages/container/enchantments%2F<id>/versions --jq '[length, .[0].name]'`
   prints `[1,"<digest>"]`, where `<digest>` is the id's `.digest` in the last JSON line of
   the run's publish step. If that entry is `{}` instead, or the count isn't 1, someone else
   published the id: delete the package, then republish by re-running all jobs of the
   merge's CI run, and approve its `publish`. Then run `gh auth refresh -r read:packages`.

   If the merge's run has a `Pending:` line without the id, treat the name as taken: add
   the Feature to no project, delete the package and republish the same way. With no
   `Pending:` line, its `pending` job failed: fix that and re-run it.
8. **Check that the package is public;** if it isn't, make it public in its GitHub settings.
   CI's `visibility` job fails while any package is private.
