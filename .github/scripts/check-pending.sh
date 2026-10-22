#!/bin/bash
# shellcheck source-path=SCRIPTDIR
# The release gate's first half: finds the Features to publish, those whose
# version isn't among the tags of their :1 yet, and fails if any one's
# changelog entry is invalid, which stops the release. Prints the ids,
# space-separated. Any failed lookup, an outage included, lists the id;
# publishing skips a version that exists. Needs GITHUB_TOKEN to see private
# packages; the changelog check runs without it.
set -euo pipefail
scripts=$(dirname "$0")
# shellcheck source=feature_ids.sh
. "$scripts/feature_ids.sh"
# shellcheck source=ghcr_lib.sh
. "$scripts/ghcr_lib.sh"
pending=()
for id in $(feature_ids); do
  version=$(jq -r .version "src/$id/devcontainer-feature.json")
  if ghcr_has "$id" "$version"; then
    continue
  fi
  env -u GITHUB_TOKEN "$scripts/check-changelog.sh" --release "$id" >&2
  pending+=("$id")
done
echo "${pending[*]}"
