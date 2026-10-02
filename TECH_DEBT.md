# Tech debt

Deliberate shortcuts, each with what pays it back.

## Pin staleness

The pins in each `pins.sh` are updated by hand ([Updating pins](docs/releasing.md#updating-pins)),
and a pin that falls behind upstream still passes its checksum, so nothing flags it.
Dependabot keeps the toolchain's npm lock current, and its security alerts cover the semble
lock.

- **Pays it back:** a scheduled workflow that opens a PR for each pin with a newer release.
