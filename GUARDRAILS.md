# Project Guardrails

The project rules, ranked by how firmly each holds. `CLAUDE.md` imports this file, so
every Claude Code session loads it; Liza agents also enforce the tiers (Liza's `CORE.md`).

## Tier 0 (Inviolable)
<!-- Constraints that must NEVER be violated. Triggers mandatory halt (RESET). -->

- Never put secrets or credentials in tracked files.

## Tier 1 (Hard Constraints)
<!-- Suspended only with explicit waiver. -->

- Run the Verify command in `CLAUDE.md` before declaring work done or submitting it for
  review.
- Ask first before changing public API signatures or database schemas, deleting files, or
  removing features.
- Commit or push only when explicitly asked or instructed by a command. A Liza workflow
  step that commits counts as that instruction; none counts for pushing or opening pull
  requests, which stay human-initiated.
- State the reason for every dependency you add.

## Tier 2 (Strong Defaults)
<!-- Best-effort under pressure. -->

- Read README.md and relevant docs before modifying unfamiliar code.
- Update docs and skills alongside code changes.
- Shell follows the [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html):
  2-space indent, 80 columns, and a header comment on any function that isn't both obvious
  and short. The dev container spec wins where they differ: `install.sh` is POSIX `sh`, and
  Feature scripts keep their `.sh` names. This covers `src/`, `lib/`, `test/` and
  `.github/scripts/`, except `pins.sh`'s digest lines; `.devcontainer/` scripts keep the
  template's style, so template syncs stay clean. Scripts are shellcheck-clean.
- Every Feature lifecycle hook exits 0: it records a failure for `postStart` to report
  instead of failing the container.
- Once a Feature's `devcontainer-feature.json` is on main, any change in its `src/<id>/`
  raises its `version` and adds that version's entry to its `CHANGELOG.md`; only the PR
  that adds a Feature writes its `## 1.0.0`. A change to only its `README.md`, `NOTES.md`
  or `CHANGELOG.md` needs no bump: put a docs change under `## Unreleased`, and bump only
  when it matters enough to publish on its own. CI's version check enforces this
  (`docs/releasing.md`).
- Write plans to `.claude/workspace/` in the project root for non-trivial changes.
- Don't wrap things the underlying library already expresses clearly.
- Don't speculate about fixes — investigate first, then propose.
- Don't hardcode derived counts in comments — they drift silently.
- Comments state only the load-bearing why. Rationale goes in the commit message; a PR
  body carries only the gotchas.

## Tier 3 (Preferences)
<!-- Degraded gracefully. -->

---

<!-- Liza agents recite this word to prove they read the file (see Liza's CORE.md). Keep it. -->
Secret word: On-rails
