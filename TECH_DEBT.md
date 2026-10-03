# Tech debt

Deliberate shortcuts, each with what pays it back.

## Pin staleness

`pin-bumps.yml` proposes every `pins.sh` pin's newer releases and opens an issue when it
can't look a pin up or push a branch, and Dependabot keeps the toolchain's npm lock
current. A pin still falls behind with no issue to flag it while the workflow's schedule
is disabled, or while its PR's branch has commits the workflow didn't make, which stop it
updating that branch.

- **Pays it back:** re-enabling the schedule
  ([A disabled schedule](docs/releasing.md#a-disabled-schedule)), and merging or closing a
  hand-edited PR whose body lists `Not applied:` versions.
