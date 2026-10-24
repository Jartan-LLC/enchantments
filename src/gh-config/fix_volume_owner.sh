# shellcheck shell=bash
# make vendor copies this into each Feature that uses it: edit
# lib/fix_volume_owner.sh, not a copy.

# Makes a volume this user's to write when the container is created, then runs
# take_back_volume. Docker seeds a fresh volume from the
# mount point's image-time owner, whose uid the uid remap may have changed
# since, so an empty volume's top directory is re-owned; one it can't read
# isn't known to be empty, so it's left alone. An empty one another user's
# container made is taken too: nothing in it is lost, and that container's
# start reports it. Fails, printing why, for the caller to record; the
# consequence completes "so ...".
fix_volume_owner() { # dir consequence
  local owner entries
  [ "$(id -u)" -eq 0 ] && return 0
  owner=$(id -u):$(id -g)
  if [ -d "$1" ] && [ ! -O "$1" ] && entries=$(ls -A "$1" 2>/dev/null) \
    && [ -z "$entries" ] && ! sudo -n chown "$owner" "$1" 2>/dev/null; then
    echo "can't take ownership of $1, an empty volume, without passwordless" \
      "sudo, so $2; run: sudo chown $owner $1"
    return 1
  fi
  take_back_volume "$1" "$2"
}

# Takes back the files a root container left in a shared volume, each link
# itself, never what it points to. Another user's files stay theirs, and it
# fails naming them: their containers may be running, and would lose their own
# 0600 files. Root never re-owns: it can write anyway. Fails, printing why, for
# the caller to record; the consequence completes "so ...".
take_back_volume() { # dir consequence
  local uid owner fix other
  uid=$(id -u)
  [ "$uid" -eq 0 ] && return 0
  [ -z "$(find "$1" ! -user "$uid" -print -quit 2>/dev/null)" ] && return 0
  owner=$uid:$(id -g)
  if [ -n "$(find "$1" -user 0 -print -quit 2>/dev/null)" ]; then
    fix="sudo find $1 -user 0 -exec chown -h $owner {} +"
    if ! sudo -n true 2>/dev/null; then
      echo "can't take back the files a root container left in $1 without" \
        "passwordless sudo, so $2; run: $fix"
      return 1
    elif ! sudo -n find "$1" -user 0 -exec chown -h "$owner" {} + \
      2>/dev/null; then
      echo "couldn't take back all the files a root container left in $1," \
        "so $2; run: $fix"
      return 1
    fi
  fi
  other=$(find "$1" ! -user "$uid" -printf '%U\n' -quit 2>/dev/null)
  [ -z "$other" ] && return 0
  echo "$1 holds files of uid $other, another user's, so $2; run every" \
    "container that shares it as uid $uid, or take it for this one, which" \
    "locks out containers running as uid $other: sudo chown -hR $owner $1"
  return 1
}
