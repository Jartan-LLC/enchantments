#!/bin/bash
# Fails when a Feature was added or removed since <base> and the root
# CHANGELOG.md gained no line, since the collection's Features are what it
# records first. Only that is checked: a change to what the docs tell
# consumers, which it also records, can't be told from a typo fix by its
# path. Run from the repository root, with <base> fetched.
set -euo pipefail
if [ "$#" -ne 1 ]; then
  echo "usage: check-root-changelog.sh <base>" >&2
  exit 2
fi
base=$1
log=CHANGELOG.md

changed=$(git diff --no-renames --name-status --diff-filter=AD "$base" HEAD \
  -- 'src/*/devcontainer-feature.json')
[ -n "$changed" ] || exit 0

# The changelog's lines, less blanks and headings, sorted for comm.
entry_lines() { grep -v -e '^[[:space:]]*$' -e '^#' | LC_ALL=C sort; }
if LC_ALL=C comm -13 <(git show "$base:$log" 2>/dev/null | entry_lines) \
  <(git show "HEAD:$log" 2>/dev/null | entry_lines) | grep -q .; then
  exit 0
fi
while read -r status json; do
  [ "$status" = A ] && how=added || how=removed
  echo "::error file=$log::${json%/devcontainer-feature.json} was $how;" \
    "add a line for it to $log"
done <<<"$changed"
exit 1
