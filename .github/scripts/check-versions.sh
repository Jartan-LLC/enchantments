#!/bin/bash
# shellcheck source-path=SCRIPTDIR
# Fails when a Feature changed since <base> against the version rule
# (docs/releasing.md, Versioning). A Feature's README.md, NOTES.md and
# CHANGELOG.md don't change what it installs, so they're exempt. Any other
# change keeps the version and adds a line under "## Unreleased". A version
# change, which the release PR makes, either rises above GHCR's highest
# version with that version's entry and nothing left under "## Unreleased",
# or returns to GHCR's highest; either way no other entry is left above
# GHCR's highest, so none names a version that never shipped. A
# failed GHCR lookup fails a version change. GHCR is asked through the
# devcontainer CLI in node_modules; GITHUB_TOKEN lets it see private
# packages. Run from the repository root, with <base> fetched.
set -euo pipefail
if [ "$#" -ne 1 ]; then
  echo "usage: check-versions.sh <base>" >&2
  exit 2
fi
base=$1
scripts=$(dirname "$0")
# shellcheck source=ghcr_lib.sh
. "$scripts/ghcr_lib.sh"
# shellcheck source=pins_lib.sh
. "$scripts/pins_lib.sh"
err=$(mktemp)
old=$(mktemp)
trap 'rm -f "$err" "$old"' EXIT

# Succeeds when the changelog gains an "## Unreleased" line since base's: a
# blank line or a bare level subheading doesn't count, and a repeated line
# does. Lines moved there from an entry above the version, as a return to the
# published version moves them, aren't new.
adds_line() { # file version
  git show "$base:$1" >"$old" 2>/dev/null || : >"$old"
  comm -13 <(known_lines "$old" "$2") <(known_lines "$1" '') | grep -q .
}

# Prints the changelog's "## Unreleased" lines, and those of its entries above
# the version (none when it's empty), but the level subheadings, sorted.
known_lines() { # file version
  local v
  {
    changelog_section "$1" Unreleased || true
    if [ -n "$2" ]; then
      sed -n 's/^## \([0-9]*\.[0-9]*\.[0-9]*\)$/\1/p' "$1" | while read -r v; do
        if version_gt "$v" "$2"; then changelog_section "$1" "$v"; fi
      done
    fi
  } | without_levels | sort
}

# Prints each "## X.Y.Z" heading's version in a changelog above the
# published version, but the one kept.
unshipped() { # file published kept
  local v
  sed -n 's/^## \([0-9]*\.[0-9]*\.[0-9]*\)$/\1/p' "$1" | while read -r v; do
    if [ "$v" != "$3" ] && version_gt "$v" "$2"; then echo "$v"; fi
  done
}

# Rename detection would list only the destination of a file moved from one
# Feature to another, missing the Feature it left.
ids=$(git diff --no-renames --name-only "$base" HEAD -- src \
  | awk -F/ 'NF > 3 || $3 !~ /^(README|NOTES|CHANGELOG)\.md$/ { print $2 }' \
  | sort -u)

failed=0
for id in $ids; do
  json=src/$id/devcontainer-feature.json
  log=src/$id/CHANGELOG.md
  [ -f "$json" ] || continue # deleted
  head_version=$(jq -r .version "$json")
  # Publishing rejects anything but semver, and a pre-release would sort wrong.
  if ! [[ "$head_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "::error file=$json::src/$id's version must be X.Y.Z, but it's" \
      "$head_version"
    failed=1
    continue
  fi
  # A new Feature writes its first version's entry.
  if ! base_json=$(git show "$base:$json" 2>/dev/null); then
    "$scripts/check-changelog.sh" --bump "$id" || failed=1
    continue
  fi
  base_version=$(jq -r .version <<<"$base_json")
  # Files a line must cover: a version change's own json doesn't count.
  code=$(git diff --no-renames --name-only "$base" HEAD -- "src/$id" \
    | awk -F/ -v v="$head_version" -v b="$base_version" '
      $3 ~ /^(README|NOTES|CHANGELOG)\.md$/ && NF == 3 { next }
      $3 == "devcontainer-feature.json" && NF == 3 && v != b { next }
      { print }')
  if [ -n "$code" ] && ! adds_line "$log" "$head_version"; then
    echo "::error file=$log::src/$id changed, so add its line under" \
      "'## Unreleased' in its CHANGELOG.md"
    failed=1
    continue
  fi
  [ "$head_version" != "$base_version" ] || continue

  # A version change: a release, or a return to the published version.
  if ! latest=$(ghcr_latest "$id" 2>"$err") || [ -z "$latest" ]; then
    cause=$(ghcr_cause "$err")
    echo "::error file=$json::src/$id's version changed, and GHCR couldn't" \
      "tell its published version${cause:+ ($cause)}"
    failed=1
    continue
  fi
  if [ "$head_version" != "$latest" ] \
    && ! version_gt "$head_version" "$latest"; then
    echo "::error file=$json::src/$id's version must rise above the" \
      "published $latest, or return to it, but it's $head_version"
    failed=1
    continue
  fi
  left=$(unshipped "$log" "$latest" "$head_version" | paste -sd, - \
    | sed 's/,/, /g')
  if [ -n "$left" ]; then
    echo "::error file=$log::src/$id's changelog has entries for $left, never" \
      "published; fold them into '## $head_version' or move them under" \
      "'## Unreleased'"
    failed=1
    continue
  fi
  if [ "$head_version" = "$latest" ]; then
    "$scripts/check-changelog.sh" --release "$id" || failed=1
  else
    "$scripts/check-changelog.sh" --bump "$id" || failed=1
  fi
done
exit "$failed"
