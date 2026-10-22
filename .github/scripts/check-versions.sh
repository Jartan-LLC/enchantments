#!/bin/bash
# shellcheck source-path=SCRIPTDIR
# Fails when a Feature changed since <base> without a version release
# (docs/releasing.md, Versioning): a higher version with its changelog entry,
# or, while base's version isn't published, that version with the change
# added to its entry. A Feature's README.md, NOTES.md and CHANGELOG.md don't
# change what it installs, so they're exempt. A higher version must be
# semver-greater, so reverting a release can't pass by restoring an older
# one, and mustn't leave an entry behind for a base version never published.
# GHCR is asked through the devcontainer CLI in node_modules; GITHUB_TOKEN
# lets it see private packages. Run from the repository root, with <base>
# fetched.
set -euo pipefail
if [ "$#" -ne 1 ]; then
  echo "usage: check-versions.sh <base>" >&2
  exit 2
fi
base=$1
scripts=$(dirname "$0")
# shellcheck source=ghcr_lib.sh
. "$scripts/ghcr_lib.sh"
err=$(mktemp)
trap 'rm -f "$err"' EXIT

# Succeeds when version a is semver-greater than b.
above() { # a b
  [ "$1" != "$2" ] && printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

# Prints the lines of the "## <version>" entry in a changelog on stdin.
entry() { # version
  awk -v heading="## $1" '
    $0 == heading { inside = 1; next }
    /^## / { inside = 0 }
    inside'
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
  if base_json=$(git show "$base:$json" 2>/dev/null); then
    base_version=$(jq -r .version <<<"$base_json")
    # Whether base's version is published, as the bots read it (pins_lib.sh,
    # unpublished): 0 at or below GHCR's highest, 1 above it, 2 the lookup
    # failed.
    published=0
    latest=$(ghcr_latest "$id" 2>"$err") || published=2
    cause=$(ghcr_cause "$err")
    if [ "$published" = 0 ] \
      && { [ -z "$latest" ] || above "$base_version" "$latest"; }; then
      published=1
    fi
    if [ "$head_version" = "$base_version" ]; then
      if [ "$published" = 0 ]; then
        echo "::error file=$json::src/$id changed and $base_version is" \
          "already published, so its version must rise above it"
        failed=1
        continue
      elif [ "$published" = 2 ]; then
        echo "::error file=$json::src/$id changed, and GHCR couldn't tell" \
          "whether $base_version is published${cause:+ ($cause)}; raise the" \
          "version above it"
        failed=1
        continue
      elif [ "$(git show "$base:$log" 2>/dev/null | entry "$base_version")" \
        = "$(entry "$base_version" <"$log")" ]; then
        echo "::error file=$log::src/$id changed under unpublished" \
          "$base_version, so add its change to the '## $base_version' entry"
        failed=1
        continue
      fi
    elif ! above "$head_version" "$base_version"; then
      echo "::error file=$json::src/$id changed, so its version must rise" \
        "above $base_version, but it's $head_version"
      failed=1
      continue
    elif grep -qxF "## $base_version" "$log" 2>/dev/null; then
      if [ "$published" = 1 ]; then
        echo "::error file=$log::$base_version was never published, so fold" \
          "its '## $base_version' entry into '## $head_version'"
        failed=1
        continue
      elif [ "$published" = 2 ]; then
        echo "::warning file=$log::couldn't tell whether $base_version is" \
          "published${cause:+ ($cause)}, so a '## $base_version' entry left" \
          "behind isn't checked"
      fi
    fi
  fi
  "$scripts/check-changelog.sh" --bump "$id" || failed=1
done
exit "$failed"
