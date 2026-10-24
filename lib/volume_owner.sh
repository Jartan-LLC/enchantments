# shellcheck shell=bash
# make vendor copies this into each Feature that uses it: edit
# lib/volume_owner.sh, not a copy.

# Makes a volume this user's to write when the container is created, then runs
# take_back_volume. Docker seeds a fresh volume from the mount point's
# image-time owner, whose uid the uid remap may have changed since, so an empty
# volume's top directory is re-owned, whoever owns it; one it can't list isn't
# known to be empty, so it's left alone. Fails, printing why and completing
# "so $2", for the caller to record.
fix_volume_owner() { # dir consequence
  local owner entries
  [ "$(id -u)" -eq 0 ] && return 0
  owner=$(id -u):$(id -g)
  if [ -d "$1" ] && [ ! -O "$1" ] && entries=$(ls -A "$1" 2>/dev/null) \
    && [ -z "$entries" ]; then
    if ! sudo -n chown "$owner" "$1" 2>/dev/null; then
      echo "can't take ownership of $1, an empty volume, without" \
        "passwordless sudo, so $2; run: sudo chown $owner $1"
      return 1
    fi
  fi
  take_back_volume "$1" "$2"
}

# Takes back the files a root container left in a shared volume; a link is
# re-owned itself, never what it points to. While another uid's files are
# there too, it takes nothing and fails naming that uid: that uid's containers
# may be running and would lose their own 0600 files, and root's files wait
# until the volume has one uid. Root never re-owns: it can write anyway. Fails,
# printing why and completing "so $2", for the caller to record.
take_back_volume() { # dir consequence
  local uid owner other take
  uid=$(id -u)
  [ "$uid" -eq 0 ] && return 0
  [ -z "$(find "$1" ! -user "$uid" -print -quit 2>/dev/null)" ] && return 0
  owner=$uid:$(id -g)
  other=$(find "$1" ! -user "$uid" ! -user 0 -printf '%U\n' -quit 2>/dev/null)
  if [ -n "$other" ]; then
    echo "$1 holds files of uid $other, not this container's uid $uid, so $2;" \
      "run every container that shares it as one uid, or take it for this" \
      "one, which locks out containers running as uid $other:" \
      "sudo chown -hR $owner $1"
    return 1
  fi
  take=(find "$1" -user 0 -exec chown -h "$owner" {} +)
  if ! sudo -n true 2>/dev/null; then
    echo "can't take back the files a root container left in $1 without" \
      "passwordless sudo, so $2; run: sudo ${take[*]}"
    return 1
  elif ! sudo -n "${take[@]}" 2>/dev/null; then
    echo "couldn't take back all the files a root container left in $1," \
      "so $2; run: sudo ${take[*]}"
    return 1
  fi
}
