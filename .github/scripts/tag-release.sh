#!/bin/bash
# shellcheck source-path=SCRIPTDIR
# Tags published Feature versions (docs/releasing.md, "Release tags").
#   tag-release.sh <commit> <id>...  gives each id's version at <commit>, once
#     it's on GHCR, the tag feature_<id>_<version> on <commit>. Exits 1 if any
#     id failed, after every id had its turn.
#   tag-release.sh --untagged  warns about each published version on GHCR
#     with no tag.
# Tags are made through the git refs API, so the checkout holds no git
# credential, and never move: one already on another commit is an error.
# Needs GH_TOKEN (contents: write to tag) and GITHUB_REPOSITORY, and
# GITHUB_TOKEN to see private packages. Run from the repository root.
set -euo pipefail
scripts=$(dirname "$0")
# shellcheck source=feature_ids.sh
. "$scripts/feature_ids.sh"
# shellcheck source=ghcr_lib.sh
. "$scripts/ghcr_lib.sh"
usage="usage: tag-release.sh <commit> <id>... | --untagged"
refs=repos/${GITHUB_REPOSITORY:?}/git

# Tags one id's version at a commit, or says why it's left untagged. Fails
# when it needs a maintainer.
tag_one() { # commit id
  local commit=$1 id=$2 json=src/$2/devcontainer-feature.json version tag
  local rc=0 err at
  if ! git cat-file -e "$commit:$json" 2>/dev/null; then
    echo "::error::$id: no $json at $commit"
    return 1
  fi
  version=$(git show "$commit:$json" | jq -r .version)
  tag=feature_${id}_$version
  ghcr_has "$id" "$version" || rc=$?
  case $rc in
    1)
      echo "$tag: not on GHCR, so not tagged"
      return 0
      ;;
    2)
      echo "::error::$tag: the GHCR lookup failed, so it's not tagged"
      return 1
      ;;
  esac
  if err=$(gh api "$refs/refs" -f ref="refs/tags/$tag" -f sha="$commit" \
    2>&1 >/dev/null); then
    echo "tagged $tag"
    return 0
  fi
  # Already there: a re-run, or an overlapping run that made it meanwhile.
  if at=$(gh api "$refs/ref/tags/$tag" --jq .object.sha 2>/dev/null); then
    if [ "$at" = "$commit" ]; then
      echo "$tag: already on this commit"
      return 0
    fi
    echo "::error::$tag already points at $at, not $commit; a tag never" \
      "moves (docs/releasing.md, Release tags)"
    return 1
  fi
  echo "::error::could not create $tag: $err"
  # The workflow's token can't tag a commit whose .github/workflows differ
  # from main's tip; other permission gaps also return 403.
  case $err in
    *"HTTP 403"*)
      echo "::error::likely cause: main's workflows changed after $commit;" \
        "tag it by hand (docs/releasing.md, Release tags)"
      ;;
  esac
  return 1
}

# Warns about each version on GHCR with no tag.
# A failed lookup warns of nothing; check-pending.sh --report, on scheduled
# and manual runs, fails on it instead.
untagged() {
  local existing id versions version tag
  existing=$(gh api --paginate "$refs/matching-refs/tags/feature_" \
    --jq '.[].ref | sub("^refs/tags/"; "")')
  for id in $(feature_ids); do
    versions=$(ghcr_versions "$id") || continue
    for version in $versions; do
      tag=feature_${id}_$version
      grep -qxF "$tag" <<<"$existing" && continue
      echo "::warning::$tag is on GHCR but has no tag; tag it by hand" \
        "(docs/releasing.md, Release tags)"
    done
  done
}

main() {
  local commit id status=0
  if [ "${1:-}" = --untagged ] && [ "$#" = 1 ]; then
    untagged
    return
  fi
  [ "$#" -ge 2 ] || { echo "$usage" >&2 && return 2; }
  commit=$(git rev-parse --verify "$1^{commit}")
  shift
  for id in "$@"; do
    tag_one "$commit" "$id" || status=1
  done
  return "$status"
}

main "$@"
