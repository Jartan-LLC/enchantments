#!/bin/bash
# shellcheck source-path=SCRIPTDIR
# Proposes newer upstream pins, from each src/<id>/pins.sh, as one PR per
# Feature on the branch pin-bumps/<id> (docs/releasing.md, "Pin-bump PRs").
# --dry-run only prints each pin's current value and any newer candidate,
# changes nothing, and exits 1 if any lookup failed. Otherwise it needs
# GH_TOKEN (the App's), APP_SLUG and GITHUB_REPOSITORY, works on origin/main,
# exits 1 when a Feature's update errors or its pins.sh can't be read (a
# failed lookup is reported, not fatal), and writes a report for
# pin-bumps-issues.sh, one tab-separated row each:
#   lookup <tool> ok|fail [reason]
#   pins   <id>   ok|fail [reason]
#   push   <id>   ok|refused [reason]
# "push ok" means the branch needs no maintainer: pushed, already up to date,
# left to its hand edits, or its PR closed. Run from the repository root.
set -euo pipefail
# An error inside $(...) stops the Feature too; build_commit runs in one.
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
# TMPDIR points into the run's directory, so every temp file, the lookups'
# included, is removed with it.
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

# The report's row kinds; the header above gives their vocabulary.
report_lookup() { # tool ok|fail [reason]
  printf 'lookup\t%s\t%s\t%s\n' "$1" "$2" "${3:-}" >>"$report"
}
report_pins() { # id ok|fail [reason]
  printf 'pins\t%s\t%s\t%s\n' "$1" "$2" "${3:-}" >>"$report"
}
report_push() { # id ok|refused [reason]
  printf 'push\t%s\t%s\t%s\n' "$1" "$2" "${3:-}" >>"$report"
}

# Prints the value of a lookup output's first "<field> " line.
field() { sed -n "s/^$2 //p" "$1" | sed -n 1p; }

# Prints a bump's From cell: a lock's moved requirements at their old
# versions, else the pin's current value.
shown_from() { # output
  local from
  from=$(field "$1" from)
  echo "${from:-$(field "$1" current)}"
}

# --- Lookups ------------------------------------------------------------------

# Looks one pin up into an output file, whose first line names the tool,
# then reports and prints it. Fails when the lookup did. Its stdin is
# /dev/null, since the caller's loop reads the pin list from stdin.
look_up_pin() { # id kind tool output
  local id=$1 kind=$2 tool=$3 out=$4 err=$4.err reason
  local lookup=lookup_${2//-/_}
  echo "tool $tool" >"$out"
  if ! declare -F "$lookup" >/dev/null; then
    echo "unknown pin kind $kind" >"$err"
  elif "$lookup" "src/$id/pins.sh" "$tool" >>"$out" 2>"$err" </dev/null; then
    report_lookup "$tool" ok
    print_pin "$id" "$kind" "$out"
    return 0
  fi
  reason=$(tail -n 1 "$err")
  reason=${reason:-no reason given}
  echo "$id $tool ($kind): lookup failed: $reason"
  report_lookup "$tool" fail "$reason"
  return 1
}

# Looks every pin of a Feature up, and prints the outputs that hold a
# candidate. Returns 1 when a lookup failed, and 2 when the pin list can't
# be read.
look_up_feature() { # id
  local id=$1 kind tool out pinned reason='' failed=0
  if ! pinned=$(pin_list "src/$id/pins.sh"); then
    reason="src/$id/pins.sh has a malformed # pin header"
  elif [ -z "$pinned" ]; then
    reason="src/$id/pins.sh has no # pin header"
  fi
  if [ -n "$reason" ]; then
    echo "$id: $reason" >&2
    report_pins "$id" fail "$reason"
    return 2
  fi
  report_pins "$id" ok
  mkdir -p "$work/$id"
  while read -r kind tool; do
    [ -n "$kind" ] || continue
    out=$work/$id/$tool.out
    if look_up_pin "$id" "$kind" "$tool" "$out" >&2; then
      [ -z "$(field "$out" candidate)" ] || echo "$out"
    else
      failed=1
    fi
  done <<<"$pinned"
  return "$failed"
}

# Prints one pin's line for the log: current value, and any candidate.
print_pin() { # id kind output
  local id=$1 kind=$2 out=$3 line candidate release
  candidate=$(field "$out" candidate)
  release=$(field "$out" release)
  line="$id $(field "$out" tool) ($kind): $(shown_from "$out")"
  if [ -n "$candidate" ]; then
    line+=" -> $candidate"
  else
    line+=", up to date"
  fi
  echo "$line"
  [ -z "$release" ] || echo "    newest release past the cooldown: $release"
  sed -n -e 's/^change /    /p' -e 's/^note /    note: /p' "$out"
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

# Prints a pin-bump PR's body: the bumps, how to act on them, and the
# Excluded: and held lines.
pr_body() { # id excluded-file output...
  local id=$1 out
  local -a held=() excluded_keys=() majors=()
  mapfile -t excluded_keys <"$2"
  shift 2
  echo "Raises \`$id\`'s pins to upstream releases at least $COOLDOWN_DAYS" \
    "days old."
  echo
  echo "| Pin | From | To |"
  echo "|---|---|---|"
  for out in "$@"; do
    echo "| \`$(field "$out" tool)\` | $(shown_from "$out") |" \
      "$(field "$out" candidate) |"
    held+=("$(field "$out" key)")
    [ "$(output_level "$out")" != major ] \
      || majors+=("\`$(field "$out" tool)\`")
  done
  if [ "${#majors[@]}" -gt 0 ]; then
    echo
    echo "**Upstream major:** ${majors[*]}. This PR releases the Feature as a" \
      "minor; if the new major changes what the Feature installs or how it" \
      "behaves, release a major instead."
  fi
  echo
  echo "\`check\` runs the Feature's tests, and merging releases it once you" \
    "approve the \`ghcr\` deployment. To skip these versions for good, close" \
    "this PR unmerged; newer versions are still proposed. Once you push a" \
    "commit here, the workflow stops updating this branch, and lists newer" \
    "versions in this description instead."
  if [ "$id" = liza ]; then
    echo
    echo "A Liza bump also needs the hand steps in \`docs/releasing.md\`" \
      "(Updating pins), committed on this branch."
  fi
  echo
  excluded_line "${excluded_keys[@]}"
  held_line "${held[@]}"
}

# On a hand-edited branch, lists the newer versions it doesn't carry.
note_not_applied() { # number body keys...
  local number=$1 body new
  body=$(body_lf "$2")
  shift 2
  new=$(body_without_not_applied "$body")
  [ "$#" = 0 ] || new+=$'\n'"$(not_applied_line "$@")"
  [ "$new" = "$body" ] \
    || pulls_api PATCH "pulls/$number" "{body: \$b}" --arg b "$new" >/dev/null
}

# Closes a PR with nothing newer to propose. Its held line goes, so the close
# excludes nothing: only a maintainer's close does.
close_pr() { # number body
  local body
  body="$(body_without_markers "$2")"$'\n\n'"$(closed_line)"
  pulls_api PATCH "pulls/$1" "{body: \$b, state: \"closed\"}" --arg b "$body" \
    >/dev/null
}

# Opens the Feature's PR, or brings an open one's title and body up to date.
upsert_pr() { # id number title body excluded-file output...
  local id=$1 number=$2 title=$3 body=$4 want="chore($1): bump pinned tools"
  local excluded_file=$5
  shift 5
  pr_body "$id" "$excluded_file" "$@" >"$work/body"
  if [ -z "$number" ]; then
    number=$(pulls_api POST pulls \
      "{title: \$t, head: \$h, base: \"main\", body: \$b}" \
      --arg t "$want" --arg h "pin-bumps/$id" --rawfile b "$work/body")
    echo "$id: opened #$number"
  elif [ "$title" != "$want" ] \
    || [ "$(cat "$work/body")" != "$(body_lf "$body")" ]; then
    pulls_api PATCH "pulls/$number" "{title: \$t, body: \$b}" \
      --arg t "$want" --rawfile b "$work/body" >/dev/null
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
  local id=$1 parent=$2 wt=$work/tree-$1 out tag a b header version level=patch
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
    printf -- "- \`%s\`: %s → %s\n" "$(field "$out" tool)" \
      "$(shown_from "$out")" "$(field "$out" candidate)" >>"$work/entry"
    sed -n 's/^change \(.*\)/  - \1/p' "$out" >>"$work/entry"
    [ "$(output_level "$out")" = patch ] || level=minor
  done
  # An upstream major is a minor here too: a major would move the :N tag that
  # consuming repos pin. pr_body flags it for a maintainer to judge.
  version=$(git show "origin/main:src/$id/devcontainer-feature.json" \
    | jq -r .version)
  version=$("bump_$level" "$version")
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
# Fails when the push was refused, which it reports and marks in
# $work/<id>.refused: the branch and PR then stay as they are, for a
# maintainer. The usual cause is main's workflow changes, which the App,
# with no workflows permission, can't push.
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
  report_push "$id" refused "$reason"
  touch "$work/$id.refused"
  return 1
}

# Brings a Feature's branch and PR in line with its newer pins (the outputs
# with a candidate). Defers to hand edits, closes the PR when nothing is
# newer, or rebuilds, pushes and opens or updates the PR. A refused push is
# reported and marked by push_branch; the caller reports every other outcome.
update_feature() { # id output...
  local id=$1 prs open number='' title='' body='' remote parent commit out
  local key held authors excluded_file=$work/excluded-$1
  local -a keep=() fresh=()
  shift
  prs=$(feature_prs "$id")
  open=$(jq -c '[.[] | select(.state == "open")] | last // empty' <<<"$prs")
  if [ -n "$open" ]; then
    number=$(jq -r .number <<<"$open")
    title=$(jq -r '.title // ""' <<<"$open")
    body=$(jq -r '.body // ""' <<<"$open")
  fi
  exclusions "$prs" >"$excluded_file"
  for out in "$@"; do
    key=$(field "$out" key)
    if ! grep -qxF "$key" "$excluded_file"; then keep+=("$out"); fi
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
      return 0
    fi
  fi

  if [ "${#keep[@]}" = 0 ]; then
    if [ -n "$number" ]; then
      close_pr "$number" "$body"
      echo "$id: closed #$number, nothing newer"
    fi
    return 0
  fi

  remote=$(git rev-parse -q --verify "refs/remotes/origin/pin-bumps/$id" \
    || true)
  parent=$(choose_parent "$id" "$number" "$remote")
  commit=$(build_commit "$id" "$parent" "${keep[@]}")
  push_branch "$id" "$remote" "$parent" "$commit" || return 0
  upsert_pr "$id" "$number" "$title" "$body" "$excluded_file" \
    "${keep[@]}"
}

# --- The run ------------------------------------------------------------------

main() {
  local id ids_found rc status=0 any_failed=0 found
  local -a ids outputs
  [ -d src ] || { echo "run from the repository root" >&2 && return 2; }
  if [ "$dry_run" = 0 ]; then
    setup_app
    git_authed fetch -q --prune origin \
      '+refs/heads/main:refs/remotes/origin/main' \
      '+refs/heads/pin-bumps/*:refs/remotes/origin/pin-bumps/*'
    git checkout -q --detach origin/main
  fi
  ids_found=$(feature_ids)
  [ -n "$ids_found" ] || { echo "no Features under src" >&2 && return 1; }
  mapfile -t ids <<<"$ids_found"
  for id in "${ids[@]}"; do
    [ -f "src/$id/pins.sh" ] || continue
    # A failed lookup leaves the Feature's branch and PR as they are.
    rc=0
    found=$(look_up_feature "$id") || rc=$?
    if [ "$rc" != 0 ]; then
      any_failed=1
      [ "$rc" != 2 ] || status=1
      continue
    fi
    [ "$dry_run" = 0 ] || continue
    mapfile -t outputs < <(printf '%s' "$found" | sed '/^$/d')
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
    elif [ ! -e "$work/$id.refused" ]; then
      report_push "$id" ok
    fi
  done
  # A dry run is CI's check that every lookup still works.
  [ "$dry_run" = 0 ] || [ "$any_failed" = 0 ] || status=1
  return "$status"
}

main
