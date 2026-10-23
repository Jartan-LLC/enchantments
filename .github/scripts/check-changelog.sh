#!/bin/bash
# shellcheck source-path=SCRIPTDIR
# Checks that a Feature's CHANGELOG.md has a non-empty "## <version>" entry for
# the version in its devcontainer-feature.json. --bump, which the version check
# runs on a release, also wants "## Unreleased" empty, so a release says
# what it ships; --release, which publishing and a return to the published
# version run, ignores it, since lines for the next release may already sit
# there. Run from the repository root.
set -euo pipefail
# shellcheck source=pins_lib.sh
. "$(dirname "$0")/pins_lib.sh"
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

if ! body=$(changelog_section "$log" "$version"); then
  echo "::error file=$log::no '## $version' entry for $id's version"
  exit 1
fi
if [ -z "$body" ]; then
  echo "::error file=$log::the '## $version' entry is empty"
  exit 1
fi
if [ "$mode" = --bump ] && unreleased=$(changelog_section "$log" Unreleased) \
  && [ -n "$unreleased" ]; then
  echo "::error file=$log::'## Unreleased' still has entries; move them" \
    "under '## $version'"
  exit 1
fi
