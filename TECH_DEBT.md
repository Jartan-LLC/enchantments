# Tech debt

Deliberate shortcuts, each with what pays it back.

## Pin staleness

`pin-bumps.yml` proposes every `pins.sh` pin's newer releases, and Dependabot keeps the
toolchain's npm lock current. A pin still falls behind while its lookup keeps failing,
while the workflow's schedule is disabled, while its branch's push keeps being refused, or
while its PR's branch has hand edits, which stop the rebuilds. It still passes its
checksum, so nothing else flags it.

- **Pays it back:** fixing the lookup a `pin-bumps: <tool> lookup failing` issue names,
  re-enabling the schedule ([A disabled schedule](docs/releasing.md#a-disabled-schedule)),
  rebasing the branch a `pin-bumps: <id> push refused` issue names, and merging or closing
  a hand-edited PR whose body lists `Not applied:` versions.

## Node's checksums are unverified

The `node` pin's digests come from nodejs.org's `SHASUMS256.txt` as published; its
signature isn't checked, so the digests rest on HTTPS and on your review of each bump.

- **Pays it back:** verifying `SHASUMS256.txt.sig` against Node's release keys in the
  lookup, once a pinned keyring is worth maintaining, or at once if nodejs.org's files are
  ever found altered.

## The semble lock's regenerate command

The command in `src/liza-toolchain/semble-requirements.txt`'s header lacks `--no-header`,
so run by hand it replaces the header with uv's own. `pin-bumps.yml` runs it with
`--no-header` and keeps the header.

- **Pays it back:** the next `liza-toolchain` release, which updates that header.
