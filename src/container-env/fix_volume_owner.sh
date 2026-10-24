# shellcheck shell=bash
# make vendor copies this into each Feature that uses it: edit
# lib/fix_volume_owner.sh, not a copy.

# Takes ownership of a volume holding anything this user doesn't own: Docker
# seeds a fresh volume from the mount point's image-time owner, and a root
# container leaves root-owned files in a shared one. Root never re-owns: it can
# write anyway, and taking a shared volume would lock every non-root container
# out of its 0600 files. sudo is optional: without it, the caller warns.
fix_volume_owner() { # dir
  [ "$(id -u)" -eq 0 ] && return 0
  [ -z "$(find "$1" ! -user "$(id -u)" -print -quit 2>/dev/null)" ] && return 0
  sudo -n chown -R "$(id -u):$(id -g)" "$1" 2>/dev/null
}
