#!/bin/bash
# shellcheck source-path=SCRIPTDIR
# Finishes Dependabot's PRs under src/ (docs/releasing.md, "Dependabot PRs
# under src/"): on each open one whose commits are all Dependabot's, pushes a
# commit, as the pin-bumps App, that lists the change under "## Unreleased"
# at its level (pins_lib.sh, add_unreleased). Lists only changes to a
# Feature's npm/package.json and npm/package-lock.json; a PR changing
# anything else under src/ is reported and left alone. Needs GH_TOKEN (the
# App's), APP_SLUG and GITHUB_REPOSITORY, and exits 1 when any PR failed,
# after every PR had its turn. Run from the repository root.
set -euo pipefail
# An error inside $(...) stops the PR too.
shopt -s inherit_errexit
here=$(dirname "$0")
# shellcheck source=pins_lib.sh
. "$here/pins_lib.sh"
# shellcheck source=app_lib.sh
. "$here/app_lib.sh"
# shellcheck source=pr_lib.sh
. "$here/pr_lib.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"; git worktree prune' EXIT

# Prints "<number> <branch> <head>" for each open PR to main from Dependabot,
# on a branch of this repository under /src/.
dependabot_prs() {
  gh api --paginate \
    "repos/$GITHUB_REPOSITORY/pulls?state=open&base=main&per_page=100" \
    --jq '.[] | select(.user.login == "dependabot[bot]"
      and (.head.ref | contains("/src/"))
      and .head.repo.full_name == env.GITHUB_REPOSITORY)
      | "\(.number) \(.head.ref) \(.head.sha)"'
}

# Prints a package.json's dependencies as {name: version}.
direct_deps() { # rev path
  git show "$1:$2" | jq -c '.dependencies // {}'
}

# Prints a package-lock.json's packages as {name: versions}, every copy's
# version "/"-joined in version order, leaving out the root and the names in
# skip.
locked() { # rev path skip-json
  git show "$1:$2" | jq -c --argjson skip "$3" '
    .packages | to_entries
    | map(select(.key != "" and .value.version != null)
      | {n: (.key | sub(".*node_modules/"; "")), v: .value.version})
    | map(select(.n as $n | $skip | index($n) | not))
    | group_by(.n)
    | map({key: .[0].n, value: (map(.v) | unique
      | sort_by(split(".") | map(tonumber? // .)) | join("/"))})
    | from_entries'
}

# Prints "<name>: <old> → <new>", "<name>: added <new>" or "<name>: removed"
# for each name whose value differs between two {name: version} objects, the
# form pins_lib.sh's output_moves reads.
moves() { # old-json new-json
  jq -rn --argjson o "$1" --argjson n "$2" '
    ($o + $n | keys[]) as $k
    | select($o[$k] != $n[$k])
    | if $o[$k] == null then "\($k): added \($n[$k])"
      elif $n[$k] == null then "\($k): removed"
      else "\($k): \($o[$k]) → \($n[$k])" end'
}

# Writes the changelog entry for a PR's npm moves, and prints its level.
npm_entry() { # base head npm-dir entry-file
  local base=$1 head=$2 pkg=$3/package.json lock=$3/package-lock.json skip
  local direct locks line level
  local -a lock_lines
  direct=$(moves "$(direct_deps "$base" "$pkg")" \
    "$(direct_deps "$head" "$pkg")")
  skip=$({ git show "$base:$pkg" && git show "$head:$pkg"; } \
    | jq -sc '[.[] | .dependencies // {} | keys[]] | unique')
  locks=$(moves "$(locked "$base" "$lock" "$skip")" \
    "$(locked "$head" "$lock" "$skip")")
  : >"$4"
  while IFS= read -r line; do
    [ -z "$line" ] || printf -- "- \`%s\`: %s\n" "${line%%: *}" "${line#*: }"
  done <<<"$direct" >>"$4"
  if [ -n "$locks" ]; then
    mapfile -t lock_lines <<<"$locks"
    { echo "- npm lock:" && printf '  - %s\n' "${lock_lines[@]}"; } >>"$4"
  fi
  [ -s "$4" ] || return 1
  # Levels follow Versioning in docs/releasing.md.
  printf '%s\n%s\n' "$direct" "$locks" | sed '/^$/d; s/^/change /' \
    >"$work/moves"
  level=$(output_level "$work/moves")
  [ "$level" = patch ] || level=minor
  echo "$level"
}

# Finishes one PR, or says why it's left as it is. Fails when the PR needs a
# maintainer: a change it can't list, or a refused push.
finish_pr() { # number branch head
  local number=$1 branch=$2 head=$3 authors base paths id level reason
  local wt=$work/tree-$1 entry=$work/entry-$1 out
  if ! git cat-file -e "$head^{commit}" 2>/dev/null; then
    echo "#$number: $branch moved since the fetch; the next run looks again"
    return 0
  fi
  authors=$(pr_authors "$number")
  if [ "$(tail -n 1 <<<"$authors")" = "$bot_login" ] \
    && ! sed '$d' <<<"$authors" | grep -qvxF 'dependabot[bot]'; then
    echo "#$number: already finished"
    return 0
  elif grep -qvxF 'dependabot[bot]' <<<"$authors"; then
    echo "#$number: has commits by others, so it's left to them"
    return 0
  fi

  base=$(git merge-base origin/main "$head")
  paths=$(git diff --no-renames --name-only "$base" "$head" -- src)
  # The paths check-versions.sh wants an Unreleased line for.
  id=$(awk -F/ 'NF > 3 || $3 !~ /^(README|NOTES|CHANGELOG)\.md$/ { print $2 }' \
    <<<"$paths" | sort -u)
  if [ -z "$id" ]; then
    echo "#$number: changes nothing that needs a release"
    return 0
  fi
  if [ "$(wc -l <<<"$id")" != 1 ] || grep -qvxF \
    -e "src/$id/npm/package.json" -e "src/$id/npm/package-lock.json" \
    <<<"$paths"; then
    echo "::error::#$number: changes more under src/ than one Feature's npm" \
      "files, which this script doesn't list; finish it by hand"
    return 1
  fi
  if ! level=$(npm_entry "$base" "$head" "src/$id/npm" "$entry"); then
    echo "::error::#$number: no npm package moved, so there's nothing to" \
      "list in the changelog; finish it by hand"
    return 1
  fi

  git worktree add -q --detach "$wt" "$head"
  add_unreleased "$wt/src/$id/CHANGELOG.md" "$level" "$entry"
  {
    echo "chore($id): list the dependency update in the changelog" \
      "[dependabot skip]"
    echo
    cat "$entry"
  } >"$work/message"
  git -C "$wt" add -A "src/$id"
  git -C "$wt" -c user.name="$bot_login" -c user.email="$bot_email" \
    commit -q -F "$work/message"
  out=$(git -C "$wt" rev-parse HEAD)
  git worktree remove --force "$wt"

  # The lease: a push Dependabot made since the fetch wins.
  if ! reason=$(lease_push "$branch" "$head" "$out"); then
    echo "::error::#$number: push refused: $reason"
    return 1
  fi
  echo "#$number: finished, as a $level change to $id"
}

main() {
  local prs number branch head rc status=0
  [ -d src ] || { echo "run from the repository root" >&2 && return 2; }
  setup_app
  git_authed fetch -q --prune origin \
    '+refs/heads/main:refs/remotes/origin/main' \
    '+refs/heads/dependabot/*:refs/remotes/origin/dependabot/*'
  prs=$(dependabot_prs)
  while read -r number branch head; do
    [ -n "$number" ] || continue
    # Each PR in a subshell with set -e of its own: an error fails the run,
    # but only after every PR had its turn.
    set +e
    (
      set -e
      finish_pr "$number" "$branch" "$head"
    ) </dev/null
    rc=$?
    set -e
    [ "$rc" = 0 ] || status=1
  done <<<"$prs"
  return "$status"
}

main
