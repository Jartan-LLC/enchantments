# Tech debt

Deliberate shortcuts, each with what pays it back.

## Pin staleness

`pin-bumps.yml` proposes every `pins.sh` pin's newer releases, and Dependabot keeps the
toolchain's npm lock current. A pin still falls behind while its lookup keeps failing,
while the workflow's schedule is disabled, or while its PR's branch has hand edits, which
stop the rebuilds. It still passes its checksum, so nothing else flags it.

- **Pays it back:** the `pin-bumps: <tool> lookup failing` issue a failing lookup opens,
  [A disabled schedule](docs/releasing.md#a-disabled-schedule) for a disabled one, and the
  PR body's `Not applied:` line for a hand-edited branch.
