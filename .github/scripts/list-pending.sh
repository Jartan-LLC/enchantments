#!/bin/bash
# Prints, space-separated, the ids whose version isn't among the tags of their
# :1 yet, after checking each one's changelog entry. The bare ref would mean
# latest, and a deleted latest would keep an id pending forever. Any failed
# lookup, an outage included, lists the id; publishing skips a version that
# exists. Needs GITHUB_TOKEN to see private packages; the changelog check runs
# without it.
set -euo pipefail
scripts=$(dirname "$0")
pending=()
for json in src/*/devcontainer-feature.json; do
  id=${json#src/}
  id=${id%%/*}
  version=$(jq -r .version "$json")
  if tags=$(node_modules/.bin/devcontainer features info tags \
    "ghcr.io/jartan-llc/enchantments/$id:1" --output-format json) \
    && jq -e --arg v "$version" '.publishedTags | index($v)' \
      <<<"$tags" >/dev/null; then
    continue
  fi
  env -u GITHUB_TOKEN "$scripts/check-changelog.sh" --release "$id" >&2
  pending+=("$id")
done
echo "${pending[*]}"
