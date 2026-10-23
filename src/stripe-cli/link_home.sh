# shellcheck shell=bash
# make vendor copies this into each Feature that uses it: edit
# lib/link_home.sh, not a copy.

# Links a path in the user's home to a volume mounted under /mnt/enchantments,
# where Feature mounts must be, since they can't name the user. A path that's
# already the volume, as when a project mounts it there itself, is left alone.
# Fails, changing nothing, when something else is in the way.
link_home() { # path target
  if [ "$1" -ef "$2" ]; then
    return 0
  elif [ -L "$1" ] || { [ -e "$1" ] && ! rmdir "$1" 2>/dev/null; }; then
    return 1
  fi
  mkdir -p "$(dirname "$1")" && ln -s "$2" "$1"
}
