#!/bin/bash
# Checks that a Feature's CHANGELOG.md has a non-empty "## <version>" entry for
# the version in its devcontainer-feature.json. --bump, which the version check
# runs on a release, also wants "## Unreleased" empty, so a release says
# what it ships; --release, which publishing and a return to the published
# version run, ignores it, since lines for the next release may already sit
# there. Run from the repository root.
set -euo pipefail
usage="usage: check-changelog.sh --bump|--release <id>"
if [ "$#" -ne 2 ] || { [ "$1" != --bump ] && [ "$1" != --release ]; }; then
  echo "$usage" >&2
  exit 2
fi
mode=$1
id=$2
log=src/$id/CHANGELOG.md
if [ ! -f "$log" ]; then
  echo "::error::src/$id has no CHANGELOG.md"
  exit 1
fi
version=$(jq -r .version "src/$id/devcontainer-feature.json")

# Prints the non-blank lines under the heading "## <title>", up to the next
# "## " heading, and fails when no line is exactly that heading.
section() { # title
  awk -v heading="## $1" '
    $0 == heading { inside = 1; found = 1; next }
    /^## / { inside = 0 }
    inside && NF { print }
    END { exit !found }' "$log"
}

if ! body=$(section "$version"); then
  echo "::error file=$log::no '## $version' entry for $id's version"
  exit 1
fi
if [ -z "$body" ]; then
  echo "::error file=$log::the '## $version' entry is empty"
  exit 1
fi
if [ "$mode" = --bump ] && unreleased=$(section Unreleased) \
  && [ -n "$unreleased" ]; then
  echo "::error file=$log::'## Unreleased' still has entries; move them" \
    "under '## $version'"
  exit 1
fi
