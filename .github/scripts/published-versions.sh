#!/bin/bash
# shellcheck source-path=SCRIPTDIR
# Prints each Feature's highest published version as one JSON object,
# {"<id>": "X.Y.Z"}, which release-pr.sh reads as PUBLISHED_VERSIONS
# (pins_lib.sh, published_of). A Feature whose lookup fails, as a
# never-published one's does, is left out with a warning naming the cause.
# Needs GITHUB_TOKEN to see private packages. Run
# from the repository root.
set -euo pipefail
scripts=$(dirname "$0")
# shellcheck source=feature_ids.sh
. "$scripts/feature_ids.sh"
# shellcheck source=ghcr_lib.sh
. "$scripts/ghcr_lib.sh"
err=$(mktemp)
trap 'rm -f "$err"' EXIT
for id in $(feature_ids); do
  if ! latest=$(ghcr_latest "$id" 2>"$err"); then
    echo "::warning::$id: the GHCR lookup failed: $(ghcr_cause "$err")" >&2
  elif [ -n "$latest" ]; then
    printf '%s\t%s\n' "$id" "$latest"
  fi
done | jq -Rnc '[inputs | split("\t") | {(.[0]): .[1]}] | add // {}'
