#!/bin/bash
# shellcheck source-path=SCRIPTDIR
# The release's first half: finds the Features to publish, those whose
# version isn't among the tags of their :1 yet, each with its release commit,
# the newest commit that set that version. Publishing stages the Feature from
# that commit (stage-release.sh), and tagging tags it, so code merged after a
# release never ships under its version, whichever run publishes it. Fails if
# any one's changelog entry is invalid, which stops the release, or if its
# release commit isn't in the checkout's history. Prints "<id>@<commit>" for
# each, space-separated. Any failed lookup, an outage included, lists the id;
# publishing skips a version that exists. Needs GITHUB_TOKEN to see private
# packages; the changelog check runs without it. Run from the repository
# root, with full history.
set -euo pipefail
scripts=$(dirname "$0")
# shellcheck source=feature_ids.sh
. "$scripts/feature_ids.sh"
# shellcheck source=ghcr_lib.sh
. "$scripts/ghcr_lib.sh"

# Prints the newest commit on HEAD's history that set the Feature's version
# to the given one: the first, going back, whose parent has another version
# or no such Feature.
release_commit() { # id version
  local json=src/$1/devcontainer-feature.json commit before
  for commit in $(git log --format=%H -- "$json"); do
    before=$(git show "$commit^:$json" 2>/dev/null | jq -r .version) \
      || before=''
    if [ "$before" != "$2" ]; then
      echo "$commit"
      return 0
    fi
  done
  return 1
}

pending=()
for id in $(feature_ids); do
  version=$(jq -r .version "src/$id/devcontainer-feature.json")
  if ghcr_has "$id" "$version"; then
    continue
  fi
  env -u GITHUB_TOKEN "$scripts/check-changelog.sh" --release "$id" >&2
  if ! commit=$(release_commit "$id" "$version"); then
    echo "::error::$id: no commit setting its version $version is in the" \
      "history" >&2
    exit 1
  fi
  pending+=("$id@$commit")
done
echo "${pending[*]}"
