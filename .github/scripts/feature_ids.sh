# shellcheck shell=bash
# Sourced by the CI scripts. Run from the repository root.

# Prints each Feature's id, one per line, in byte order: a Feature is a folder
# under src/ holding a devcontainer-feature.json.
feature_ids() {
  find src -mindepth 2 -maxdepth 2 -name devcontainer-feature.json \
    -printf '%h\n' | cut -d/ -f2 | LC_ALL=C sort
}
