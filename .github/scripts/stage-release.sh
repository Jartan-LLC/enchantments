#!/bin/bash
# shellcheck source-path=SCRIPTDIR
# Builds the directory publishing reads: each pending id's src/<id> from the
# working tree, which the run tested, and every other published Feature from
# its highest published version's tag (docs/releasing.md, Release tags).
# Publishing skips a version that exists, but lists every Feature it's given
# in devcontainer-collection.json, so leaving one out would drop it from
# there. A Feature never published and not pending is left out. With no tag
# yet, as when a tag job failed or hasn't run, a Feature whose working-tree
# version is the published one comes from the newest commit that set that
# version, which under a squash merge is the commit it was published from.
# Fails, rather than stage an incomplete collection, when a published
# Feature's lookup fails, or it has no tag and that fallback doesn't
# apply. Needs GITHUB_TOKEN to see private packages.
# Run from the repository root, with the tags fetched.
set -euo pipefail
scripts=$(dirname "$0")
# shellcheck source=feature_ids.sh
. "$scripts/feature_ids.sh"
# shellcheck source=ghcr_lib.sh
. "$scripts/ghcr_lib.sh"
usage="usage: stage-release.sh <dir> <id>..."
[ "$#" -ge 2 ] || { echo "$usage" >&2 && exit 2; }
dir=$1
shift
err=$(mktemp)
trap 'rm -f "$err"' EXIT
mkdir -p "$dir/src"
ids=$(feature_ids)
tree_version() { jq -r .version "src/$1/devcontainer-feature.json"; }

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
for id in "$@"; do
  if ! grep -qxF "$id" <<<"$ids"; then
    echo "::error::no Feature $id" >&2
    exit 1
  fi
done
for id in $ids; do
  if printf '%s\n' "$@" | grep -qxF "$id"; then
    cp -R "src/$id" "$dir/src/"
    continue
  fi
  if ! latest=$(ghcr_latest "$id" 2>"$err"); then
    # GHCR answers a Feature never published as it does an outage.
    [ -n "$(git tag -l "feature_${id}_*")" ] || continue
    echo "::error::$id: the GHCR lookup failed: $(ghcr_cause "$err")" >&2
    exit 1
  fi
  [ -n "$latest" ] || continue
  tag=feature_${id}_$latest
  if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    git archive "$tag" "src/$id" | tar -x -C "$dir"
  elif [ "$(tree_version "$id")" = "$latest" ] \
    && commit=$(release_commit "$id" "$latest"); then
    echo "::warning::$id: no tag $tag yet, so it's staged from $commit," \
      "which set its version" >&2
    git archive "$commit" "src/$id" | tar -x -C "$dir"
  else
    echo "::error::$id: no tag $tag to stage its published $latest from" >&2
    exit 1
  fi
done
