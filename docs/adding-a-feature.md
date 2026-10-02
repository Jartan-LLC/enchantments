# Adding a Feature

1. **Create `src/<id>/`** with `devcontainer-feature.json` at `"version": "1.0.0"`,
   `install.sh` and the payload, a `NOTES.md`, and a `CHANGELOG.md` whose only entry is
   `## 1.0.0`. In `NOTES.md` and `CHANGELOG.md`, write links as absolute GitHub URLs or code
   spans.
2. **Add its tests** in `test/<id>/`, and add the id to the `alpine`, `javascript-node` and
   `root-user` scenarios in `test/_global/scenarios.json`.
3. **Pin what it downloads.** For an npm lockfile, add a `dependabot.yml` block; for anything
   else, add a `pins.sh` entry of one of the kinds in [Updating pins](releasing.md#updating-pins).
   Either way, add a row to that table saying how to update it.
4. **Document it:** copy a sibling's `docs/features/<id>.md` and add it to the Features
   toctree in `docs/index.md`, add a row to the Feature list in the root `README.md`, and add
   it to [Choosing Features](choosing.md).
5. **Run `make readmes`** and commit the generated `src/<id>/README.md`, then `make check`.
6. **Open the PR.** It needs a green `check`.
7. **Publish it.** After the merge, CI waits for your approval of the `ghcr` deployment.
   Before approving:
   1. Check that the id is on the `Pending:` line of the run's `pending` job log.
   2. Run `gh auth refresh -s read:packages`, then check that
      `gh api orgs/Jartan-LLC/packages/container/enchantments%2F<id>` returns 404. Anything
      else, 403 included, fails the check: reject the deployment. A package linked to this
      repo proves nothing: GHCR links whatever repo the package's source label names.

   After the release, check that
   `gh api orgs/Jartan-LLC/packages/container/enchantments%2F<id>/versions --jq '[length, .[0].name]'`
   prints `[1,"<digest>"]`, where `<digest>` is the id's `.digest` in the last JSON line of
   the run's publish step. If that entry is `{}` instead, or the count isn't 1, someone else
   published the id: delete the package and republish. Then run
   `gh auth refresh -r read:packages`.

   If no run after the merge has the id on its `Pending:` line, treat the name as taken: add
   the Feature to no project, delete the package and republish.
8. **Confirm the package is public** in its GitHub settings; if it's private, make it public.
   CI's `visibility` job fails while any package is private.
