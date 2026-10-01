# shellcheck shell=bash
# Vendored into each Feature that uses it; edit it here, then run `make vendor`.

# A shared volume may come from another container, or Docker may have seeded it from a
# root-owned mount point. sudo is optional: without it the caller warns and continues.
fix_volume_owner() {  # dir
    [ -O "$1" ] || sudo -n chown -R "$(id -u):$(id -g)" "$1" 2>/dev/null
}
