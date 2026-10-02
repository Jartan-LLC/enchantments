# Adding a Feature

## What the PR touches

- `src/<id>/`: `devcontainer-feature.json` at `"version": "1.0.0"` (every consumer key is
  `:1`), `install.sh`, the payload, `NOTES.md`, and `CHANGELOG.md` with its `## 1.0.0`
  entry. Run `make readmes` and commit the generated `README.md`.
- `test/<id>/`: its scenarios.
- `docs/features/<id>.md`, copied from a sibling, and its entry in `docs/index.md`'s
  Features toctree.
- Its row in the root `README.md`'s Feature list and in [Choosing Features](choosing.md).
- Its id in the three image-coverage scenarios in `test/_global/scenarios.json`
  (`alpine`, `javascript-node`, `root-user`); the test loop fails until it's there.
- For each pin: a `dependabot.yml` block if Dependabot updates it as a whole (an npm
  lockfile), else a `pins.sh` entry of one of the kinds in
  [Updating pins](releasing.md#updating-pins). Either way, a row there saying how to
  update it.

Links in `NOTES.md` and `CHANGELOG.md` must be absolute GitHub URLs or code spans: the docs
site includes both from `docs/`, and the strict build fails on a relative link.

## The first release

The merge's run on main lists the new id in `pending` and waits for a `ghcr` approval.
Any Jartan-LLC repo can pre-create the package name, so check it isn't squatted while
approving:

1. That run's `pending` output lists the id. If no run that lists it ever asks for
   approval, someone pre-published that exact version: treat the id as squatted, add it to
   no consumer, delete the package and republish.
2. `gh auth refresh -s read:packages`, then
   `gh api orgs/Jartan-LLC/packages/container/enchantments%2F<id>` must return 404. Any
   other answer, 403 included, fails the check. The package's linked repository proves
   nothing: GHCR links whatever repo the image's source label names.
3. After the release,
   `gh api orgs/Jartan-LLC/packages/container/enchantments%2F<id>/versions --jq '[length, .[0].name]'`
   prints `[1,"<digest>"]`, where `<digest>` is the id's `.digest` in the JSON line the
   approved run's publish step prints last. If that entry is `{}` (check with
   `jq -e '."<id>".digest'`), the run skipped the id as already published, so someone else
   published it: delete the package and republish. Then
   `gh auth refresh -r read:packages`.

If any check fails, reject the deployment, or delete the package, then republish.

Then make the package public, in its settings on GitHub: consumers pull anonymously, and
CI's `visibility` job stays red until every package is.
