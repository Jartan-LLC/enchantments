#!/bin/bash
# Writes the test matrix and the base commit to $GITHUB_OUTPUT. The matrix is
# every Feature and _global on both architectures, all or nothing: consumer
# scenarios build sibling Features from source, so one Feature's change re-runs
# every Feature that composes it. With no base (a manual run, a failed fetch)
# everything runs, rather than risk skipping a change. EVENT and BEFORE carry
# github.event_name and github.event.before.
set -euo pipefail
case "$EVENT" in
  pull_request) base=HEAD^1 ;;
  push) git fetch -q --depth=1 origin "$BEFORE" && base=$BEFORE ;;
esac
# The versions job compares against this, as a commit.
if [ -n "${base:-}" ]; then
  base=$(git rev-parse "$base")
fi

ids=$(find src -mindepth 2 -maxdepth 2 -name devcontainer-feature.json \
  -printf '%h\n' | cut -d/ -f2 | sort)
if [ "$EVENT" = schedule ] && [ -z "$ids" ]; then
  echo "::error::no Features found under src"
  exit 1
fi
tested='^(src/|lib/|test/|\.github/scripts/|package\.json$|package-lock\.json$'
tested+='|\.github/workflows/ci\.yml$|Makefile$)'
# Captured, not piped: grep -q exits at its first match, and under pipefail the
# SIGPIPE that kills a long git diff would read as no match.
changed=''
if [ -n "${base:-}" ]; then
  changed=$(git diff --name-only "$base" HEAD)
fi
if [ "$EVENT" = schedule ] || [ -z "${base:-}" ] \
  || grep -qE "$tested" <<<"$changed"; then
  matrix=$({
    printf '%s\n' "$ids"
    echo _global
  } | jq -Rnc '[inputs | select(. != "")] as $ids
    | [$ids[] as $id | ("ubuntu-24.04", "ubuntu-24.04-arm") as $runner
      | {id: $id, runner: $runner}]')
else
  matrix='[]'
fi
echo "matrix=$matrix" >>"$GITHUB_OUTPUT"
echo "base=${base:-}" >>"$GITHUB_OUTPUT"
