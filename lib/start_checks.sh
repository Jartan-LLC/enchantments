# shellcheck shell=bash
# make vendor copies this into each Feature that uses it: edit
# lib/start_checks.sh, not a copy. Needs record_failure.sh.

# Succeeds while the id has failures not yet reported. A postStart check then
# records nothing: a pending failure likely explains what it would find, and
# the next start checks again.
pending_failures() { # id
  # shellcheck disable=SC2154 # set by record_failure.sh
  [ -s "$enchantments_failures_dir/$1.failures" ]
}

# Records a failure without printing it, for a postStart check: the
# report_failures that follows prints it. Where it can't record, it prints.
record_at_start() { # id message...
  local id=$1
  shift
  { mkdir -p "$enchantments_failures_dir" \
    && printf '%s\n' "$*" >>"$enchantments_failures_dir/$id.failures"; } \
    2>/dev/null || echo "Warning: $id: $*" >&2
}

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
  local owner
  owner=$(id -u):$(id -g)
  [ "$(id -u)" -eq 0 ] && return 0
  [ -z "$(find "$2" -user 0 -print -quit 2>/dev/null)" ] && return 0
  sudo -n find "$2" -user 0 -exec chown -h "$owner" {} + 2>/dev/null \
    || record_at_start "$1" "can't take back the files a root container left" \
      "in $2 without passwordless sudo, so $3; run: sudo find $2 -user 0" \
      "-exec chown -h $owner {} +"
}
