#!/bin/bash
# shellcheck source-path=SCRIPTDIR
# Proposes newer upstream pins, from each src/<id>/pins.sh, as one PR per
# Feature on the branch pin-bumps/<id> (docs/releasing.md, "Pin-bump PRs").
# --dry-run only prints each pin's current value and any newer candidate,
# and changes nothing. Otherwise it needs GH_TOKEN (the App's), APP_SLUG and
# GITHUB_REPOSITORY, works on origin/main, and writes a report for
# pin-bumps-issues.sh. Run from the repository root.
set -euo pipefail
# So an error inside $(...) stops the Feature too, as in build_commit.
shopt -s inherit_errexit
here=$(dirname "$0")
# shellcheck source=pins_lib.sh
. "$here/pins_lib.sh"
# shellcheck source=pin_lookups.sh
. "$here/pin_lookups.sh"
# shellcheck source=feature_ids.sh
. "$here/feature_ids.sh"

COOLDOWN_DAYS=7
usage="usage: pin-bumps.sh [--dry-run] [--report <file>]"
dry_run=0
report=/dev/null
while [ "$#" -gt 0 ]; do
  case $1 in
    --dry-run) dry_run=1 ;;
    --report) report=${2:?$usage} && shift ;;
    *) echo "$usage" >&2 && exit 2 ;;
  esac
  shift
done
CUTOFF=$(date -u -d "$COOLDOWN_DAYS days ago" +%s)
export DRY_RUN=$dry_run CUTOFF COOLDOWN_DAYS
: >"$report"
# Every temp file, the lookups' included, goes and is removed with the run's.
work=$(mktemp -d)
export TMPDIR=$work
if [ "$dry_run" = 1 ]; then
  trap 'rm -rf "$work"' EXIT
else
  trap 'rm -rf "$work"; git worktree prune' EXIT
fi

# Set by setup_app, for real runs: the App's commit identity, and the header
# its git requests carry.
bot_login=''
bot_email=''
auth=''

setup_app() {
  : "${GH_TOKEN:?}" "${APP_SLUG:?}" "${GITHUB_REPOSITORY:?}"
  bot_login="${APP_SLUG}[bot]"
  bot_email="$(gh api "users/$APP_SLUG%5Bbot%5D" --jq .id)+$bot_login"
  bot_email+="@users.noreply.github.com"
  auth="AUTHORIZATION: basic $(printf 'x-access-token:%s' "$GH_TOKEN" \
    | base64 -w0)"
  echo "::add-mask::${auth#AUTHORIZATION: basic }"
}

# Runs git with the App's auth header, in the environment rather than argv.
git_authed() {
  GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=http.https://github.com/.extraheader \
    GIT_CONFIG_VALUE_0="$auth" git "$@"
}

report_row() { # lookup|push tool|id ok|fail|refused [reason]
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "${4:-}" >>"$report"
}

# Prints the value of a lookup output's first "<field> " line.
field() { sed -n "s/^$2 //p" "$1" | sed -n 1p; }

print_pin() { # id kind tool output
  local line candidate release
  candidate=$(field "$4" candidate)
  release=$(field "$4" release)
  line="$1 $3 ($2): $(field "$4" current)"
  if [ -n "$candidate" ]; then
    line+=" -> $candidate"
  else
    line+=", up to date"
  fi
  echo "$line"
  [ -z "$release" ] || echo "    newest aged release: $release"
  sed -n -e 's/^change /    /p' -e 's/^note /    note: /p' "$4"
}

# --- Pull requests ------------------------------------------------------------

# Sends a JSON object built by jq from --arg pairs to a pulls endpoint, and
# prints the PR's number.
pulls_api() { # method path jq-filter args...
  local method=$1 path=$2 filter=$3
  shift 3
  jq -n "$@" "$filter" >"$work/request.json"
  gh api -X "$method" "repos/$GITHUB_REPOSITORY/$path" \
    --input "$work/request.json" --jq .number
}

# Prints the Feature's PRs, oldest first, found by the owner-qualified head
# so a fork's same-named branch never counts.
feature_prs() { # id
  local query="head=${GITHUB_REPOSITORY%%/*}:pin-bumps/$1"
  query+="&state=all&per_page=100"
  gh api "repos/$GITHUB_REPOSITORY/pulls?$query" --jq 'sort_by(.created_at)'
}

# Prints the keys never to propose again: the latest PR's Excluded: line,
# and its held versions when it was closed unmerged.
exclusions() { # prs-json
  local latest body
  latest=$(jq -c 'last // empty' <<<"$1")
  [ -n "$latest" ] || return 0
  body=$(jq -r '.body // ""' <<<"$latest")
  {
    body_excluded "$body"
    if jq -e '.state == "closed" and .merged_at == null' <<<"$latest" \
      >/dev/null; then
      body_held "$body"
    fi
  } | sort -u
}

pr_body() { # id output...
  local id=$1 out
  local -a held=() excluded=()
  shift
  echo "Raises \`$id\`'s pins to upstream releases at least $COOLDOWN_DAYS" \
    "days old."
  echo
  echo "| Pin | From | To |"
  echo "|---|---|---|"
  for out in "$@"; do
    echo "| \`$(basename "$out" .out)\` | $(field "$out" current) |" \
      "$(field "$out" candidate) |"
    held+=("$(field "$out" key)")
  done
  echo
  echo "\`check\` runs the Feature's tests, and merging releases it once you" \
    "approve the \`ghcr\` deployment. To skip these versions for good, close" \
    "this PR unmerged; a newer version is proposed again. Commits you push" \
    "here stop the rebuilds until it's closed."
  if [ "$id" = liza ]; then
    echo
    echo "A Liza bump needs the hand steps in \`docs/releasing.md\`" \
      "(Updating pins): push them onto this branch."
  fi
  echo
  mapfile -t excluded <"$work/excluded"
  excluded_line "${excluded[@]}"
  held_line "${held[@]}"
}

# On a hand-edited branch, lists the newer versions it doesn't carry.
note_not_applied() { # number body keys...
  local number=$1 body new
  body=$(body_lf "$2")
  shift 2
  new=$(grep -v '^Not applied: ' <<<"$body" || true)
  [ "$#" = 0 ] || new+=$'\n'"$(not_applied_line "$@")"
  [ "$new" = "$body" ] \
    || pulls_api PATCH "pulls/$number" "{body: \$b}" --arg b "$new" >/dev/null
}

# Closes a PR with nothing newer to propose. Its held line goes, so the close
# excludes nothing: only a maintainer's close does.
close_pr() { # number body
  local body
  body="$(body_without_markers "$2")"$'\n\n'"Closed: nothing newer."
  pulls_api PATCH "pulls/$1" "{body: \$b, state: \"closed\"}" --arg b "$body" \
    >/dev/null
}

upsert_pr() { # id number body output...
  local id=$1 number=$2 body=$3 title="chore($1): bump pinned tools"
  shift 3
  pr_body "$id" "$@" >"$work/body"
  if [ -z "$number" ]; then
    number=$(pulls_api POST pulls \
      "{title: \$t, head: \$h, base: \"main\", body: \$b}" \
      --arg t "$title" --arg h "pin-bumps/$id" --rawfile b "$work/body")
    echo "$id: opened #$number"
  elif [ "$(cat "$work/body")" != "$(body_lf "$body")" ]; then
    pulls_api PATCH "pulls/$number" "{title: \$t, body: \$b}" \
      --arg t "$title" --rawfile b "$work/body" >/dev/null
    echo "$id: updated #$number"
  fi
}

# --- The branch ---------------------------------------------------------------

# Prints the commit to rebuild on: the open PR's own parent while the
# Feature's files on main haven't moved, else main. A push moving the branch
# past main's workflow changes would be refused.
choose_parent() { # id number remote
  local main
  main=$(git rev-parse origin/main)
  if [ -n "$2" ] && [ -n "$3" ] \
    && git diff --quiet "$3^" "$main" -- "src/$1" "test/$1"; then
    git rev-parse "$3^"
  else
    echo "$main"
  fi
}

# Commits the bumps on the parent as the App, in a checkout of its own, and
# prints the commit.
build_commit() { # id parent output...
  local id=$1 parent=$2 wt=$work/tree-$1 out tag a b header version
  shift 2
  git worktree add -q --detach "$wt" "$parent"
  : >"$work/entry"
  for out in "$@"; do
    while read -r tag a b; do
      case $tag in
        set) pin_set "$wt/src/$id/pins.sh" "$a" "$b" ;;
        lock)
          header=$(awk '!/^#/ { exit } { print }' "$wt/$a")
          { printf '%s\n' "$header" && cat "$b"; } | overwrite "$wt/$a"
          ;;
      esac
    done <"$out"
    printf -- "- \`%s\`: %s → %s\n" "$(basename "$out" .out)" \
      "$(field "$out" current)" "$(field "$out" candidate)" >>"$work/entry"
    sed -n 's/^change \(.*\)/  - \1/p' "$out" >>"$work/entry"
  done
  version=$(git show "origin/main:src/$id/devcontainer-feature.json" \
    | jq -r .version)
  version=$(bump_minor "$version")
  set_version "$wt/src/$id/devcontainer-feature.json" "$version"
  add_changelog_entry "$wt/src/$id/CHANGELOG.md" "$version" "$work/entry"
  { echo "chore($id): bump pinned tools" && echo && cat "$work/entry"; } \
    >"$work/message"
  git -C "$wt" add -A "src/$id"
  git -C "$wt" -c user.name="$bot_login" -c user.email="$bot_email" \
    commit -q -F "$work/message"
  git -C "$wt" rev-parse HEAD
  git worktree remove --force "$wt"
}

# Pushes the commit unless the branch already holds its tree on its parent.
# A refused push leaves the branch and PR as they are, and is reported for a
# maintainer; the usual cause is main's workflow changes, which the App, with
# no workflows permission, can't push.
push_branch() { # id remote parent commit
  local id=$1 remote=$2 parent=$3 commit=$4 out reason
  if [ -n "$remote" ] && [ "$(git rev-parse "$remote^")" = "$parent" ] \
    && [ "$(git rev-parse "$remote^{tree}")" \
      = "$(git rev-parse "$commit^{tree}")" ]; then
    echo "$id: pin-bumps/$id unchanged"
    return 0
  fi
  if out=$(git_authed push \
    --force-with-lease="refs/heads/pin-bumps/$id:$remote" origin \
    "$commit:refs/heads/pin-bumps/$id" 2>&1); then
    echo "$id: pushed pin-bumps/$id"
    return 0
  fi
  reason=$(grep -m 1 -i -e refusing -e rejected <<<"$out" \
    || tail -n 1 <<<"$out")
  echo "$id: push refused: $reason"
  report_row push "$id" refused "$reason"
  return 1
}

update_feature() { # id output...
  local id=$1 prs open number='' body='' remote parent commit out key held
  local authors
  local -a keep=() fresh=()
  shift
  prs=$(feature_prs "$id")
  open=$(jq -c '[.[] | select(.state == "open")] | last // empty' <<<"$prs")
  if [ -n "$open" ]; then
    number=$(jq -r .number <<<"$open")
    body=$(jq -r '.body // ""' <<<"$open")
  fi
  exclusions "$prs" >"$work/excluded"
  for out in "$@"; do
    key=$(field "$out" key)
    if ! grep -qxF "$key" "$work/excluded"; then keep+=("$out"); fi
  done

  # Hand edits win: list what's newer than the branch holds, and leave it.
  if [ -n "$number" ]; then
    authors=$(gh api --paginate \
      "repos/$GITHUB_REPOSITORY/pulls/$number/commits?per_page=100" \
      --jq '.[] | .author.login // "?"')
    if grep -qvxF "$bot_login" <<<"$authors"; then
      held=$(body_held "$body")
      for out in "${keep[@]}"; do
        key=$(field "$out" key)
        if ! grep -qxF "$key" <<<"$held"; then fresh+=("$key"); fi
      done
      note_not_applied "$number" "$body" "${fresh[@]}"
      report_row push "$id" ok
      return 0
    fi
  fi

  if [ "${#keep[@]}" = 0 ]; then
    if [ -n "$number" ]; then
      close_pr "$number" "$body"
      echo "$id: closed #$number, nothing newer"
    fi
    report_row push "$id" ok
    return 0
  fi

  remote=$(git rev-parse -q --verify "refs/remotes/origin/pin-bumps/$id" \
    || true)
  parent=$(choose_parent "$id" "$number" "$remote")
  commit=$(build_commit "$id" "$parent" "${keep[@]}")
  push_branch "$id" "$remote" "$parent" "$commit" || return 0
  upsert_pr "$id" "$number" "$body" "${keep[@]}"
  report_row push "$id" ok
}

# --- The run ------------------------------------------------------------------

if [ "$dry_run" = 0 ]; then
  setup_app
  git_authed fetch -q --prune origin \
    '+refs/heads/main:refs/remotes/origin/main' \
    '+refs/heads/pin-bumps/*:refs/remotes/origin/pin-bumps/*'
  git checkout -q --detach origin/main
fi

status=0
for id in $(feature_ids); do
  pins=src/$id/pins.sh
  [ -f "$pins" ] || continue
  mkdir -p "$work/$id"
  failed=0
  outputs=()
  while read -r kind tool; do
    out=$work/$id/$tool.out
    lookup=lookup_${kind//-/_}
    if ! declare -F "$lookup" >/dev/null; then
      echo "unknown pin kind $kind" >"$work/$id/$tool.err"
      false
    else
      "$lookup" "$pins" "$tool" >"$out" 2>"$work/$id/$tool.err" </dev/null
    fi || {
      failed=1
      reason=$(tail -n 1 "$work/$id/$tool.err")
      echo "$id $tool ($kind): lookup failed: ${reason:-no reason given}"
      report_row lookup "$tool" fail "${reason:-no reason given}"
      continue
    }
    report_row lookup "$tool" ok
    print_pin "$id" "$kind" "$tool" "$out"
    [ -z "$(field "$out" candidate)" ] || outputs+=("$out")
  done < <(pin_list "$pins")
  # A failed lookup leaves the Feature's branch and PR as they are.
  [ "$dry_run" = 0 ] && [ "$failed" = 0 ] || continue
  # Each Feature in a subshell with set -e of its own: an error fails the
  # run, but only after every Feature had its turn.
  set +e
  (
    set -e
    update_feature "$id" "${outputs[@]}"
  )
  rc=$?
  set -e
  if [ "$rc" != 0 ]; then
    echo "::error::$id: pin bumps failed (exit $rc)"
    status=1
  fi
done
exit "$status"
