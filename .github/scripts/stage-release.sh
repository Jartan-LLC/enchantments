#!/bin/bash
# Copies each pending Feature's src/<id> from its release commit
# (check-pending.sh's "<id>@<commit>" output) into <dir>/src, which publishing
# then reads, so each version ships as that commit had it. Run from the
# repository root.
set -euo pipefail
usage="usage: stage-release.sh <dir> <id>@<commit>..."
[ "$#" -ge 2 ] || { echo "$usage" >&2 && exit 2; }
dir=$1
shift
mkdir -p "$dir/src"
for release in "$@"; do
  id=${release%@*}
  commit=${release#*@}
  [ "$id" != "$release" ] || { echo "$usage" >&2 && exit 2; }
  git archive "$commit" "src/$id" | tar -x -C "$dir"
done
