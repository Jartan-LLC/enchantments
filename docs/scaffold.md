# Syncing template updates

You can still pull in later improvements to the template. How depends on how your repository started.

```bash
# One-time, either way: add the template as an 'upstream' remote
git remote add upstream https://github.com/Jartan-LLC/scaffold.git  # this template's repo
git fetch upstream
```

**If you used *Use this template*** — the button on the template's GitHub page — GitHub started your history
fresh, so there is nothing to merge: `git merge upstream/main` stops at `fatal: refusing to merge
unrelated histories`. Port changes by hand instead, and keep the newest upstream commit you have
dealt with — ported or deliberately skipped — in `.scaffold-sync` at your repository root:

```bash
# First time only: the template commit your repository was created from
git rev-list -1 --before="$(git log --reverse --format=%cI | head -1)" upstream/main > .scaffold-sync

git log --oneline --reverse "$(cat .scaffold-sync)"..upstream/main  # not yet dealt with, oldest first
git show <sha>                          # the change to port; apply the equivalent by hand
echo <sha> > .scaffold-sync             # once everything up to <sha> is ported or skipped
```

Commit `.scaffold-sync` with the port, so the file always matches what the repository contains.

**If you forked this repository**, the history is shared and the merge works:

```bash
git checkout -b template-update
git merge upstream/main   # resolve conflicts, keeping your customizations
```

Open a PR either way, so CI runs before the changes land.
