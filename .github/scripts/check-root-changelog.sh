#!/bin/bash
# Fails when a Feature was added or removed since <base> and no line new to
# the root CHANGELOG.md names it; a rename is a removal and an addition, so
# its line names both. A new line is one base's changelog lacks, other than a
# blank or a heading, so a reworded line counts too. Only this is checked: a
# change to what the docs tell consumers, which the changelog also records,
# can't be told from a typo fix by its path. Run from the repository root,
# with <base> fetched.
set -euo pipefail
if [ "$#" -ne 1 ]; then
  echo "usage: check-root-changelog.sh <base>" >&2
  exit 2
fi
base=$1
log=CHANGELOG.md

changed=$(git diff --no-renames --name-status --diff-filter=AD "$base" HEAD \
  -- ':(glob)src/*/devcontainer-feature.json')
[ -n "$changed" ] || exit 0

entry_lines() { grep -v -e '^[[:space:]]*$' -e '^#' | LC_ALL=C sort; }
new=$(LC_ALL=C comm -13 <(git show "$base:$log" 2>/dev/null | entry_lines) \
  <(git show "HEAD:$log" 2>/dev/null | entry_lines))
status=0
while read -r change json; do
  id=${json#src/}
  id=${id%/devcontainer-feature.json}
  grep -qF -- "$id" <<<"$new" && continue
  [ "$change" = A ] && how=added || how=removed
  echo "::error file=$log::src/$id was $how; add a line naming it to $log"
  status=1
done <<<"$changed"
exit "$status"
