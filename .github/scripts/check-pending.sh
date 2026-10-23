#!/bin/bash
# shellcheck source-path=SCRIPTDIR
# The release's first half: finds the Features to publish, those whose
# version isn't among the tags of their :1 yet, and fails if any one's
# changelog entry is invalid, which stops the release. With <since>, a
# Feature counts only if its version differs from <since>'s, or <since> has
# no such Feature: a push publishes the versions it changed, from its own
# commit, which its run tested, so code merged later never ships under them.
# With --report, which scheduled runs use, it lists every version missing
# from GHCR as an error, and fails if there's any. Prints the ids,
# space-separated. Any failed lookup, an
# outage included, lists the id; publishing skips a version that exists.
# Needs GITHUB_TOKEN to see private packages; the changelog check runs
# without it.
set -euo pipefail
if [ "$#" -gt 1 ]; then
  echo "usage: check-pending.sh [<since> | --report]" >&2
  exit 2
fi
since=${1:-}
report=0
if [ "$since" = --report ]; then
  report=1
  since=''
fi
scripts=$(dirname "$0")
# shellcheck source=feature_ids.sh
. "$scripts/feature_ids.sh"
# shellcheck source=ghcr_lib.sh
. "$scripts/ghcr_lib.sh"
pending=()
for id in $(feature_ids); do
  json=src/$id/devcontainer-feature.json
  version=$(jq -r .version "$json")
  if [ -n "$since" ] && [ "$(git show "$since:$json" 2>/dev/null \
    | jq -r .version 2>/dev/null)" = "$version" ]; then
    continue
  fi
  if ghcr_has "$id" "$version"; then
    continue
  fi
  env -u GITHUB_TOKEN "$scripts/check-changelog.sh" --release "$id" >&2
  pending+=("$id")
done
if [ "$report" = 1 ] && [ "${#pending[@]}" -gt 0 ]; then
  echo "::error::not on GHCR at main's version: ${pending[*]}. If a release" \
    "waits for your approval, approve it; if GHCR couldn't be asked, retry;" \
    "otherwise re-run its release's CI run, or withdraw it" \
    "(docs/releasing.md, Releasing a change)"
  exit 1
fi
echo "${pending[*]}"
