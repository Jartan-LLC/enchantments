#!/bin/bash
# shellcheck source-path=SCRIPTDIR
# The release's first half: finds the Features to publish, those whose
# version isn't among the tags of their :1 yet, and fails if any one's
# changelog entry is invalid, which stops the release. With <since>, a
# Feature counts only if its version differs from <since>'s, or <since> has
# no such Feature: a push publishes the versions it changed, so a merge
# after a release, but before its publish, doesn't publish its own code
# under that version. Prints the ids, space-separated. Any failed lookup, an
# outage included, lists the id; publishing skips a version that exists.
# Needs GITHUB_TOKEN to see private packages; the changelog check runs
# without it.
set -euo pipefail
if [ "$#" -gt 1 ]; then
  echo "usage: check-pending.sh [<since>]" >&2
  exit 2
fi
since=${1:-}
scripts=$(dirname "$0")
# shellcheck source=feature_ids.sh
. "$scripts/feature_ids.sh"
# shellcheck source=ghcr_lib.sh
. "$scripts/ghcr_lib.sh"
pending=()
for id in $(feature_ids); do
  json=src/$id/devcontainer-feature.json
  version=$(jq -r .version "$json")
  if [ -n "$since" ] && [ "$(git show "$since:$json" 2>/dev/null \
    | jq -r .version 2>/dev/null)" = "$version" ]; then
    continue
  fi
  if ghcr_has "$id" "$version"; then
    continue
  fi
  env -u GITHUB_TOKEN "$scripts/check-changelog.sh" --release "$id" >&2
  pending+=("$id")
done
echo "${pending[*]}"
