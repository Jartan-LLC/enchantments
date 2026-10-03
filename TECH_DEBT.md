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

## Node's checksums are unverified

The `node` pin's digests come from nodejs.org's `SHASUMS256.txt` as published; its
signature isn't checked, so the digests rest on HTTPS and on your review of each bump.

- **Pays it back:** verifying `SHASUMS256.txt.sig` against Node's release keys in the
  lookup ([#14](https://github.com/Jartan-LLC/enchantments/issues/14)); at once if
  nodejs.org's files are ever found altered.
