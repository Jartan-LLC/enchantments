#!/bin/bash
# shellcheck source-path=SCRIPTDIR
# Keeps one release PR open on the branch release (docs/releasing.md,
# "Release PRs"). It holds every Feature whose files, apart from README.md,
# NOTES.md and CHANGELOG.md, changed since its published version's release
# tag: the version raised by the level of its "## Unreleased" lines
# (pins_lib.sh, unreleased_level), and those lines moved into the version's
# entry. A Feature whose version on main isn't the published one, as while
# its release is under way, is left out. Needs GH_TOKEN (the App's),
# APP_SLUG, GITHUB_REPOSITORY and PUBLISHED_VERSIONS (published-versions.sh),
# and works on origin/main. Exits 1, after every Feature had its turn, when
# one can't be released or the PR can't be kept, and appends to a report for
# pin-bumps-issues.sh, one tab-separated row each:
#   release      <id>    ok|fail [reason]
#   release-push release ok|refused [reason]
# Run from the repository root.
set -euo pipefail
shopt -s inherit_errexit
here=$(dirname "$0")
# shellcheck source=pins_lib.sh
. "$here/pins_lib.sh"
# shellcheck source=app_lib.sh
. "$here/app_lib.sh"
# shellcheck source=pr_lib.sh
. "$here/pr_lib.sh"
# shellcheck source=feature_ids.sh
. "$here/feature_ids.sh"

usage="usage: release-pr.sh [--report <file>]"
report=/dev/null
while [ "$#" -gt 0 ]; do
  case $1 in
    --report) report=${2:?$usage} && shift ;;
    *) echo "$usage" >&2 && exit 2 ;;
  esac
  shift
done
branch=release
work=$(mktemp -d)
trap 'rm -rf "$work"; git worktree prune' EXIT

# Prints "include <published> <version> <level>" when the Feature is to be
# released, "fail <reason>" when it can't be, and nothing otherwise, saying
# why on stderr.
plan_feature() { # id
  local id=$1 version published tag level changed
  version=$(jq -r .version "src/$id/devcontainer-feature.json")
  published=$(published_of "$id")
  if [ -z "$published" ]; then
    if [ -n "$(git tag -l "feature_${id}_*")" ]; then
      echo "fail its GHCR lookup failed, so its published version is unknown"
    else
      echo "$id: never published, so left out" >&2
    fi
    return 0
  fi
  if [ "$version" != "$published" ]; then
    echo "$id: main's $version isn't published yet, so left out" >&2
    return 0
  fi
  tag=feature_${id}_$published
  if ! git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    echo "fail there's no tag $tag to compare main with; tag it by hand" \
      "(docs/releasing.md, Release tags)"
    return 0
  fi
  changed=$(git diff --no-renames --name-only "$tag" origin/main -- "src/$id" \
    | awk -F/ 'NF > 3 || $3 !~ /^(README|NOTES|CHANGELOG)\.md$/')
  if [ -z "$changed" ]; then
    echo "$id: nothing to release since $tag" >&2
    return 0
  fi
  level=$(unreleased_level "src/$id/CHANGELOG.md")
  if [ -z "$level" ]; then
    echo "fail src/$id changed since $tag, but its '## Unreleased' has no" \
      "line to release"
    return 0
  fi
  echo "include $published $("bump_$level" "$published") $level"
}

# Prints the PR's body: the releases, then how to act on it.
pr_body() { # rows-file
  local id published version level
  echo "Releases the Features below: merging this PR is the release" \
    "(\`docs/releasing.md\`, Release PRs)."
  echo
  echo "| Feature | Published | Release | Level |"
  echo "|---|---|---|---|"
  while read -r id published version level; do
    echo "| \`$id\` | $published | $version | $level |"
  done <"$1"
  echo
  echo "Each version raises the published one by the largest level among its" \
    "\`## Unreleased\` lines: a line is a patch unless it sits under" \
    "\`### Minor\` or \`### Major\`. To change a version or an entry, or to" \
    "leave a Feature out, push a commit here; the workflow then stops" \
    "updating this branch. Close this PR to have the next run rebuild it."
}

# Commits the releases on the parent as the App, in a checkout of its own,
# and prints the commit.
build_commit() { # parent rows-file
  local wt=$work/tree id published version level subject=''
  git worktree add -q --detach "$wt" "$1"
  : >"$work/lines"
  while read -r id published version level; do
    set_version "$wt/src/$id/devcontainer-feature.json" "$version"
    add_changelog_entry "$wt/src/$id/CHANGELOG.md" "$version" /dev/null
    subject+="${subject:+, }$id $version"
    echo "- $id: $published → $version ($level)" >>"$work/lines"
  done <"$2"
  { echo "chore: release $subject" && echo && cat "$work/lines"; } \
    >"$work/message"
  git -C "$wt" add -A src
  git -C "$wt" -c user.name="$bot_login" -c user.email="$bot_email" \
    commit -q -F "$work/message"
  git -C "$wt" rev-parse HEAD
  git worktree remove --force "$wt"
}

# Brings the release branch and PR in line with the releases: defers to hand
# edits, closes the PR when there's nothing to release, or rebuilds, pushes
# and opens or updates it. Fails when the push is refused, after reporting
# it.
update_pr() { # rows-file
  local rows=$1 prs open number='' title='' body='' remote parent commit
  local reason want
  prs=$(branch_prs "$branch")
  open=$(jq -c '[.[] | select(.state == "open")] | last // empty' <<<"$prs")
  if [ -n "$open" ]; then
    number=$(jq -r .number <<<"$open")
    title=$(jq -r '.title // ""' <<<"$open")
    body=$(jq -r '.body // ""' <<<"$open")
    if grep -qvxF "$bot_login" <<<"$(pr_authors "$number")"; then
      echo "release: #$number has commits the workflow didn't make, so it's" \
        "left as it is"
      return 0
    fi
  fi

  if [ ! -s "$rows" ]; then
    if [ -n "$number" ]; then
      pulls_api PATCH "pulls/$number" '{state: "closed"}' >/dev/null
      echo "release: closed #$number, nothing to release"
    fi
    return 0
  fi

  remote=$(git rev-parse -q --verify "refs/remotes/origin/$branch" || true)
  parent=$(choose_parent "$number" "$remote" src)
  commit=$(build_commit "$parent" "$rows")
  if holds_commit "$remote" "$parent" "$commit"; then
    echo "release: $branch unchanged"
  elif reason=$(lease_push "$branch" "$remote" "$commit"); then
    echo "release: pushed $branch"
  else
    echo "release: push refused: $reason"
    printf 'release-push\t%s\trefused\t%s\n' "$branch" "$reason" >>"$report"
    return 1
  fi

  want=$(git log -1 --format=%s "$commit")
  pr_body "$rows" >"$work/body"
  if [ -z "$number" ]; then
    number=$(pulls_api POST pulls \
      "{title: \$t, head: \$h, base: \"main\", body: \$b}" \
      --arg t "$want" --arg h "$branch" --rawfile b "$work/body")
    echo "release: opened #$number"
  elif [ "$title" != "$want" ] \
    || [ "$(cat "$work/body")" != "$(body_lf "$body")" ]; then
    pulls_api PATCH "pulls/$number" "{title: \$t, body: \$b}" \
      --arg t "$want" --rawfile b "$work/body" >/dev/null
    echo "release: updated #$number"
  fi
}

main() {
  local id plan status=0 remote rc
  [ -d src ] || { echo "run from the repository root" >&2 && return 2; }
  # A failed published-versions job leaves it empty: no Feature can be
  # placed, so nothing changes.
  if [ -z "${PUBLISHED_VERSIONS:-}" ]; then
    echo "::error::no published versions to release against, so the" \
      "release PR is left as it is"
    return 1
  fi
  setup_app
  remote=$(git_authed ls-remote origin "refs/heads/$branch" | cut -f1)
  git_authed fetch -q origin '+refs/heads/main:refs/remotes/origin/main' \
    '+refs/tags/feature_*:refs/tags/feature_*'
  if [ -n "$remote" ]; then
    git_authed fetch -q origin \
      "+refs/heads/$branch:refs/remotes/origin/$branch"
  else
    git update-ref -d "refs/remotes/origin/$branch"
  fi
  git checkout -q --detach origin/main

  : >"$work/rows"
  for id in $(feature_ids); do
    plan=$(plan_feature "$id")
    case $plan in
      include\ *)
        echo "$id ${plan#include }" >>"$work/rows"
        printf 'release\t%s\tok\t\n' "$id" >>"$report"
        ;;
      fail\ *)
        echo "::error::$id: ${plan#fail }, so it's left out of the release"
        printf 'release\t%s\tfail\t%s\n' "$id" "${plan#fail }" >>"$report"
        status=1
        ;;
      *) printf 'release\t%s\tok\t\n' "$id" >>"$report" ;;
    esac
  done
  # In a subshell with set -e of its own, since a caller's || or if would turn
  # it off: an error stops the update, and a refused push reported itself.
  set +e
  (
    set -e
    update_pr "$work/rows"
  )
  rc=$?
  set -e
  if [ "$rc" = 0 ]; then
    printf 'release-push\t%s\tok\t\n' "$branch" >>"$report"
  else
    echo "::error::release: the release PR couldn't be kept (exit $rc)"
    status=1
  fi
  return "$status"
}

main
