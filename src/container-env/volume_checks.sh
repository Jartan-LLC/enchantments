# shellcheck shell=bash
# make vendor copies this into each Feature that uses it: edit
# lib/volume_checks.sh, not a copy. Needs record_failure.sh and
# start_checks.sh.

# Prints how to redo a link onCreate makes: run it again, first moving aside
# whatever is in the way.
relink_advice() { # path onCreate-path
  if [ -e "$1" ] || [ -L "$1" ]; then
    echo "move it aside, then run: bash $2"
  else
    echo "run: bash $2"
  fi
}

# Takes back the files a root container left in a shared volume, or records
# why it can't. Other users' files stay theirs: their containers may be
# running, and would lose their own 0600 files. A link is re-owned itself,
# never what it points to.
take_back_root_files() { # id dir consequence
  local owner fix
  [ "$(id -u)" -eq 0 ] && return 0
  [ -z "$(find "$2" -user 0 -print -quit 2>/dev/null)" ] && return 0
  owner=$(id -u):$(id -g)
  fix="sudo find $2 -user 0 -exec chown -h $owner {} +"
  if ! sudo -n true 2>/dev/null; then
    record_at_start "$1" "can't take back the files a root container left" \
      "in $2 without passwordless sudo, so $3; run: $fix"
  elif ! sudo -n find "$2" -user 0 -exec chown -h "$owner" {} + \
    2>/dev/null; then
    record_at_start "$1" "couldn't take back all the files a root container" \
      "left in $2, so $3; run: $fix"
  fi
}
