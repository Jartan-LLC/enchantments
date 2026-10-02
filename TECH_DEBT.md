# Tech debt

Deliberate shortcuts, each with what pays it back.

## Pin staleness

A pinned tool that falls behind upstream still passes its checksum, so no test notices.

- **Paid back by:** Dependabot for the toolchain's npm lock (`src/liza-toolchain/npm`),
  whose vulnerability alerts also cover the semble lock; and, for every `pins.sh` pin, the
  scheduled `pin-bumps.yml` workflow, once it's merged. Until then, pins move by hand
  ([Updating pins](docs/releasing.md#updating-pins)).
- **Watch:** GitHub disables a public repo's scheduled workflows after 60 days with no
  activity. If `gh workflow list --all` shows one disabled, re-enable it with
  `gh workflow enable <file>`.
