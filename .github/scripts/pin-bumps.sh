#!/bin/bash
# shellcheck source-path=SCRIPTDIR
# shellcheck disable=SC2016 # backticks are Markdown, $names are jq's
# Proposes newer upstream pins, from each src/<id>/pins.sh, as one PR per
# Feature on the branch pin-bumps/<id> (docs/releasing.md, "Pin-bump PRs").
# --dry-run only prints each pin's current value and any newer candidate,
# and changes nothing. Otherwise it needs GH_TOKEN (the App's), APP_SLUG and
# GITHUB_REPOSITORY, works on origin/main, and writes a report for
# pin-bumps-issues.sh. Run from the repository root.
set -euo pipefail
here=$(dirname "$0")
# shellcheck source=pins_lib.sh
. "$here/pins_lib.sh"
# shellcheck source=pin_lookups.sh
. "$here/pin_lookups.sh"
# shellcheck source=feature_ids.sh
. "$here/feature_ids.sh"

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
export DRY_RUN=$dry_run
CUTOFF=$(date -u -d '7 days ago' +%s)
export CUTOFF
: >"$report"
work=$(mktemp -d)
trap 'rm -rf "$work"; git worktree prune' EXIT

# Prints the value of a lookup output's first "<field> " line.
field() { sed -n "s/^$2 //p" "$1" | head -1; }

print_pin() { # id kind tool output
  local line current candidate release
  current=$(field "$4" current)
  candidate=$(field "$4" candidate)
  release=$(field "$4" release)
  line="$1 $3 ($2): $current"
  if [ -n "$candidate" ]; then
    line+=" -> $candidate"
  else
    line+=", up to date"
  fi
  echo "$line"
  [ -z "$release" ] || echo "    newest aged release: $release"
  sed -n 's/^change /    /p' "$4"
}

# Prints a list of tool@value keys as "`a`, `b`", or "none".
key_list() { # keys...
  [ "$#" -gt 0 ] || { echo none && return 0; }
  printf '`%s`, ' "$@" | sed 's/, $//'
}

# Prints the PR body for a set of bumps.
pr_body() { # id excluded-keys-file output...
  local id=$1 excluded=$2 out tool held=()
  shift 2
  echo "Raises \`$id\`'s pins to upstream releases at least 7 days old."
  echo
  echo "| Pin | From | To |"
  echo "|---|---|---|"
  for out in "$@"; do
    tool=$(basename "$out" .out)
    echo "| \`$tool\` | $(field "$out" current) | $(field "$out" candidate) |"
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
  local -a keys
  mapfile -t keys <"$excluded"
  echo "Excluded: $(key_list "${keys[@]}")"
  echo "<!-- pin-bumps held: ${held[*]} -->"
}

# Sends a JSON object built by jq from --arg pairs to a pulls endpoint.
pulls_api() { # method path jq-filter args...
  local method=$1 path=$2 filter=$3
  shift 3
  jq -n "$@" "$filter" >"$work/request.json"
  gh api -X "$method" "repos/$GITHUB_REPOSITORY/$path" \
    --input "$work/request.json" --jq .number
}

# Applies the bumps to a checkout of the parent, and commits them as the App.
build_commit() { # id parent output...
  local id=$1 parent=$2 wt=$work/tree out tag a b lock header old new
  shift 2
  git worktree add -q --detach "$wt" "$parent"
  : >"$work/entry"
  for out in "$@"; do
    while read -r tag a b; do
      case $tag in
        set) pin_set "$wt/src/$id/pins.sh" "$a" "$b" ;;
        lock)
          header=$(awk '!/^#/ { exit } { print }' "$wt/$a")
          { printf '%s\n' "$header" && cat "$b"; } >"$work/lock"
          cat "$work/lock" >"$wt/$a"
          ;;
      esac
    done <"$out"
    printf -- '- `%s`: %s → %s\n' "$(basename "$out" .out)" \
      "$(field "$out" current)" "$(field "$out" candidate)" >>"$work/entry"
    sed -n 's/^change \(.*\)/  - \1/p' "$out" >>"$work/entry"
  done
  old=$(git show "origin/main:src/$id/devcontainer-feature.json" \
    | jq -r .version)
  new=$(bump_minor "$old")
  sed -i "s/\(\"version\": *\"\)[^\"]*\"/\1$new\"/" \
    "$wt/src/$id/devcontainer-feature.json"
  [ "$(jq -r .version "$wt/src/$id/devcontainer-feature.json")" = "$new" ] \
    || { echo "can't set $id's version to $new" >&2 && return 1; }
  add_changelog_entry "$wt/src/$id/CHANGELOG.md" "$new" "$work/entry"
  { echo "chore($id): bump pinned tools" && echo && cat "$work/entry"; } \
    >"$work/message"
  git -C "$wt" add -A "src/$id"
  git -C "$wt" -c user.name="$bot_login" -c user.email="$bot_email" \
    commit -q -F "$work/message"
}

update_feature() { # id output...
  local id=$1 head=pin-bumps/$1 repo=$GITHUB_REPOSITORY prs latest open
  local number='' remote parent main commit out key body push_out
  local latest_body authors=''
  shift
  prs=$(gh api \
    "repos/$repo/pulls?head=${repo%%/*}:$head&state=all&per_page=100")
  latest=$(jq -c 'sort_by(.created_at) | last // empty' <<<"$prs")
  open=$(jq -c '[.[] | select(.state == "open")] | first // empty' <<<"$prs")
  [ -z "$open" ] || number=$(jq -r .number <<<"$open")
  latest_body=''
  [ -z "$latest" ] || latest_body=$(jq -r '.body // ""' <<<"$latest")
  {
    body_excluded "$latest_body"
    if [ -n "$latest" ] && jq -e '.state == "closed" and .merged_at == null' \
      <<<"$latest" >/dev/null; then
      body_held "$latest_body"
    fi
  } | sort -u >"$work/excluded"
  local -a keep=()
  for out in "$@"; do
    key=$(field "$out" key)
    [ -n "$key" ] && ! grep -qxF "$key" "$work/excluded" && keep+=("$out")
  done

  # Hand edits win: list what's newer, and leave the branch alone.
  [ -z "$number" ] || authors=$(gh api --paginate \
    "repos/$repo/pulls/$number/commits?per_page=100" \
    --jq '.[] | .author.login // "?"')
  if [ -n "$authors" ] && grep -qvxF "$bot_login" <<<"$authors"; then
    body=$(jq -r '.body // ""' <<<"$open" | grep -v '^Not applied:' || true)
    if [ "${#keep[@]}" -gt 0 ]; then
      local -a keys=()
      for out in "${keep[@]}"; do keys+=("$(field "$out" key)"); done
      body+=$'\n'"Not applied: $(key_list "${keys[@]}"), since this branch"
      body+=" has commits from someone else."
    fi
    [ "$body" = "$(jq -r '.body // ""' <<<"$open")" ] \
      || pulls_api PATCH "pulls/$number" '{body: $b}' --arg b "$body" >/dev/null
    printf 'push\t%s\tok\n' "$id" >>"$report"
    return 0
  fi

  if [ "${#keep[@]}" = 0 ]; then
    if [ -n "$number" ]; then
      body="$(jq -r '.body // ""' <<<"$open")"$'\n\n'"Closed: nothing newer."
      pulls_api PATCH "pulls/$number" '{body: $b, state: "closed"}' \
        --arg b "$body" >/dev/null
      echo "$id: closed #$number, nothing newer"
    fi
    printf 'push\t%s\tok\n' "$id" >>"$report"
    return 0
  fi

  # Rebuild on the current parent unless the Feature moved on main.
  main=$(git rev-parse origin/main)
  remote=$(git rev-parse -q --verify "refs/remotes/origin/$head" || true)
  parent=$main
  if [ -n "$number" ] && [ -n "$remote" ] \
    && git diff --quiet "$remote^" "$main" -- "src/$id" "test/$id"; then
    parent=$(git rev-parse "$remote^")
  fi
  build_commit "$id" "$parent" "${keep[@]}"
  commit=$(git -C "$work/tree" rev-parse HEAD)
  if [ -n "$remote" ] && [ "$(git rev-parse "$remote^")" = "$parent" ] \
    && [ "$(git rev-parse "$remote^{tree}")" = \
      "$(git rev-parse "$commit^{tree}")" ]; then
    echo "$id: $head unchanged"
  elif ! push_out=$(git -c "http.https://github.com/.extraheader=$auth" push \
    --force-with-lease="refs/heads/$head:$remote" origin \
    "$commit:refs/heads/$head" 2>&1); then
    git worktree remove --force "$work/tree"
    # The App has no workflows permission, so moving the branch past a
    # workflow change on main is refused: a maintainer rebases it by hand.
    if grep -q 'without `workflows` permission' <<<"$push_out"; then
      echo "$id: push refused, main has workflow changes"
      printf 'push\t%s\trefused\n' "$id" >>"$report"
      return 0
    fi
    echo "$push_out" >&2
    return 1
  else
    echo "$id: pushed $head"
  fi
  git worktree remove --force "$work/tree"
  pr_body "$id" "$work/excluded" "${keep[@]}" >"$work/body"
  if [ -n "$number" ]; then
    [ "$(cat "$work/body")" = "$(jq -r '.body // ""' <<<"$open")" ] \
      || pulls_api PATCH "pulls/$number" '{title: $t, body: $b}' \
        --arg t "chore($id): bump pinned tools" --rawfile b "$work/body" \
        >/dev/null
  else
    number=$(pulls_api POST pulls \
      '{title: $t, head: $h, base: "main", body: $b}' \
      --arg t "chore($id): bump pinned tools" --arg h "$head" \
      --rawfile b "$work/body")
    echo "$id: opened #$number"
  fi
  printf 'push\t%s\tok\n' "$id" >>"$report"
}

if [ "$dry_run" = 0 ]; then
  : "${GH_TOKEN:?}" "${APP_SLUG:?}" "${GITHUB_REPOSITORY:?}"
  bot_login="${APP_SLUG}[bot]"
  bot_email="$(gh api "users/$APP_SLUG%5Bbot%5D" --jq .id)+$bot_login"
  bot_email+="@users.noreply.github.com"
  auth="AUTHORIZATION: basic $(printf 'x-access-token:%s' "$GH_TOKEN" \
    | base64 -w0)"
  echo "::add-mask::${auth#AUTHORIZATION: basic }"
  git fetch -q --prune origin '+refs/heads/main:refs/remotes/origin/main' \
    '+refs/heads/pin-bumps/*:refs/remotes/origin/pin-bumps/*'
  git checkout -q --detach origin/main
fi

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
      reason=$(tail -1 "$work/$id/$tool.err")
      echo "$id $tool ($kind): lookup failed: $reason"
      printf 'lookup\t%s\tfail\t%s\n' "$tool" "$reason" >>"$report"
      continue
    }
    printf 'lookup\t%s\tok\n' "$tool" >>"$report"
    print_pin "$id" "$kind" "$tool" "$out"
    [ -z "$(field "$out" candidate)" ] || outputs+=("$out")
  done < <(pin_list "$pins")
  # A failed lookup leaves the Feature's branch and PR as they are.
  [ "$dry_run" = 0 ] && [ "$failed" = 0 ] || continue
  update_feature "$id" "${outputs[@]}"
done
