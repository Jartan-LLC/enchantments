#!/bin/bash
# shellcheck source-path=SCRIPTDIR
# Prints each Feature's highest published version as one JSON object,
# {"<id>": "X.Y.Z"}, which the bots read as PUBLISHED_VERSIONS (pins_lib.sh,
# published_of). A Feature whose lookup fails, as a never-published one's
# does, is left out, so its bump falls back to raising main's version. Needs
# GITHUB_TOKEN to see private packages. Run from the repository root.
set -euo pipefail
scripts=$(dirname "$0")
# shellcheck source=feature_ids.sh
. "$scripts/feature_ids.sh"
# shellcheck source=ghcr_lib.sh
. "$scripts/ghcr_lib.sh"
for id in $(feature_ids); do
  if latest=$(ghcr_latest "$id" 2>/dev/null) && [ -n "$latest" ]; then
    printf '%s\t%s\n' "$id" "$latest"
  fi
done | jq -Rnc '[inputs | split("\t") | {(.[0]): .[1]}] | add // {}'
