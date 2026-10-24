# shellcheck shell=bash
# make vendor copies this into each Feature that uses it: edit
# lib/volume_checks.sh, not a copy.

# Prints how to redo a link onCreate makes: run it again, first moving aside
# whatever is in the way.
relink_advice() { # path onCreate-path
  if [ -e "$1" ] || [ -L "$1" ]; then
    echo "move it aside, then run: bash $2"
  else
    echo "run: bash $2"
  fi
}
