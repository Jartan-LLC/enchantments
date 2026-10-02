#!/bin/bash
# Fails when a Feature changed since <base> without a higher version and that
# version's changelog entry. A Feature's README.md, NOTES.md and CHANGELOG.md
# don't change what it installs, so they're exempt. The version must be
# semver-greater, so reverting a release can't pass by restoring an older
# one. Run from the repository root, with <base> fetched.
set -euo pipefail
if [ "$#" -ne 1 ]; then
  echo "usage: check-versions.sh <base>" >&2
  exit 2
fi
base=$1
scripts=$(dirname "$0")

# Rename detection would list only the destination of a file moved from one
# Feature to another, missing the Feature it left.
ids=$(git diff --no-renames --name-only "$base" HEAD -- src \
  | awk -F/ 'NF > 3 || $3 !~ /^(README|NOTES|CHANGELOG)\.md$/ { print $2 }' \
  | sort -u)

failed=0
for id in $ids; do
  json=src/$id/devcontainer-feature.json
  [ -f "$json" ] || continue # deleted
  head_version=$(jq -r .version "$json")
  if base_json=$(git show "$base:$json" 2>/dev/null); then
    base_version=$(jq -r .version <<<"$base_json")
    if [ "$head_version" = "$base_version" ] || ! printf '%s\n%s\n' \
      "$base_version" "$head_version" | sort -V -C; then
      echo "::error file=$json::src/$id changed, so its version must rise" \
        "above $base_version, but it's $head_version"
      failed=1
      continue
    fi
  fi
  "$scripts/check-changelog.sh" --bump "$id" || failed=1
done
exit "$failed"
