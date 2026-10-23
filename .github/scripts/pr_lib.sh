# shellcheck shell=bash
# The branches and PRs the pin-bumps App keeps, for pin-bumps.sh and
# release-pr.sh. Needs GITHUB_REPOSITORY, git_authed (app_lib.sh) and a
# work directory in $work. Sourced.

# Sends a JSON object built by jq from --arg pairs to a pulls endpoint, and
# prints the PR's number.
pulls_api() { # method path jq-filter args...
  local method=$1 path=$2 filter=$3
  shift 3
  # shellcheck disable=SC2154 # work is the sourcing script's
  jq -n "$@" "$filter" >"$work/request.json"
  gh api -X "$method" "repos/$GITHUB_REPOSITORY/$path" \
    --input "$work/request.json" --jq .number
}

# Prints the branch's PRs, oldest first, found by the owner-qualified head so
# a fork's same-named branch never counts.
branch_prs() { # branch
  local query="head=${GITHUB_REPOSITORY%%/*}:$1"
  query+="&state=all&per_page=100"
  gh api "repos/$GITHUB_REPOSITORY/pulls?$query" --jq 'sort_by(.created_at)'
}

# Prints each of the PR's commit authors' login, "?" for one GitHub can't
# match to an account.
pr_authors() { # number
  gh api --paginate \
    "repos/$GITHUB_REPOSITORY/pulls/$1/commits?per_page=100" \
    --jq '.[] | .author.login // "?"'
}

# Prints the commit to rebuild on: the open PR's own parent while paths on
# main haven't moved, else main. A push moving the branch past main's
# workflow changes would be refused.
choose_parent() { # number remote paths...
  local number=$1 remote=$2 main
  shift 2
  main=$(git rev-parse origin/main)
  if [ -n "$number" ] && [ -n "$remote" ] \
    && git diff --quiet "$remote^" "$main" -- "$@"; then
    git rev-parse "$remote^"
  else
    echo "$main"
  fi
}

# Succeeds when the remote branch already holds the commit's tree on the same
# parent, so there's nothing to push.
holds_commit() { # remote parent commit
  [ -n "$1" ] && [ "$(git rev-parse "$1^")" = "$2" ] \
    && [ "$(git rev-parse "$1^{tree}")" = "$(git rev-parse "$3^{tree}")" ]
}

# Pushes the commit to the branch, leased on its remote value (empty when it
# doesn't exist). Prints git's reason when the push is refused. The usual
# cause is main's workflow changes, which the App, with no workflows
# permission, can't push.
lease_push() { # branch remote commit
  local out
  if out=$(git_authed push --force-with-lease="refs/heads/$1:$2" origin \
    "$3:refs/heads/$1" 2>&1); then
    return 0
  fi
  grep -m 1 -i -e refusing -e rejected <<<"$out" || tail -n 1 <<<"$out"
  return 1
}
