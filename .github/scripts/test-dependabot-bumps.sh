#!/bin/bash
# shellcheck source-path=SCRIPTDIR
# Tests dependabot-bumps.sh offline, against a local bare remote and a stub gh
# that lists the PRs and their commits' authors.
set -uo pipefail
scripts=$(cd "$(dirname "$0")" && pwd)
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
# shellcheck source=test_lib.sh
. "$scripts/test_lib.sh"

origin=$root/origin.git
export ORIGIN=$origin PRS=$root/prs.json
echo '[]' >"$PRS"
mkdir -p "$root/bin"
cat >"$root/bin/gh" <<'STUB'
#!/bin/bash
# Stub gh: "api [--paginate] <path> [--jq <filter>]".
shift
path='' filter=''
while [ "$#" -gt 0 ]; do
  case $1 in
    --paginate) ;;
    --jq) filter=$2 && shift ;;
    *) path=$1 ;;
  esac
  shift
done
out() { if [ -n "$filter" ]; then jq -r "$filter"; else cat; fi; }
pulls=repos/example/repo/pulls
case $path in
  "users/pinbot%5Bbot%5D") echo '{"id": 42}' | out ;;
  # Each PR's head is its branch's, as GitHub serves it.
  "$pulls?state=open&base=main&per_page=100")
    jq -c '.[]' "$PRS" | while read -r pr; do
      sha=$(git -C "$ORIGIN" rev-parse "refs/heads/$(jq -r .head.ref <<<"$pr")")
      jq -c --arg s "$sha" '.head.sha = $s' <<<"$pr"
    done | jq -s . | out
    ;;
  "$pulls/"*"/commits?per_page=100")
    n=${path#"$pulls/"} && n=${n%%/*}
    ref=$(jq -r --argjson n "$n" '.[] | select(.number == $n) | .head.ref' \
      "$PRS")
    # A competing push to RACE_PR's branch, once, after the script's fetch
    # and before its own.
    if [ -f "${RACE:-}" ] && [ "$n" = "${RACE_PR:-}" ]; then
      rm "$RACE"
      git -C "$RACER" push -q origin "HEAD:$ref"
    fi
    git -C "$ORIGIN" log --reverse --format=%ae "main..$ref" \
      | sed -e 's/^49699333+dependabot\[bot\]@.*/dependabot[bot]/; t' \
        -e 's/^42+pinbot\[bot\]@.*/pinbot[bot]/; t' -e 's/.*/someone/' \
      | jq -R '{author: {login: .}}' | jq -s . | out
    ;;
  *) echo "stub gh: unexpected path $path" >&2 && exit 1 ;;
esac
STUB
chmod +x "$root/bin/gh"

# main: a Feature with npm tools, one of them holding two copies of dep-a.
seed=$root/seed
git init -q -b main "$seed"
mkdir -p "$seed/src/demo/npm"
printf '{\n  "id": "demo",\n  "version": "1.0.0"\n}\n' \
  >"$seed/src/demo/devcontainer-feature.json"
printf '## 1.0.0\n\n- First release.\n' >"$seed/src/demo/CHANGELOG.md"
echo 'echo install' >"$seed/src/demo/install.sh"
echo '{"dependencies": {"demo-tool": "1.0.0"}}' \
  >"$seed/src/demo/npm/package.json"
lock() { # demo-tool dep-a extra-packages-json
  jq -n --arg t "$1" --arg a "$2" --argjson x "$3" '{lockfileVersion: 3,
    packages: ({"": {dependencies: {"demo-tool": $t}},
      "node_modules/demo-tool": {version: $t},
      "node_modules/demo-tool/node_modules/dep-a": {version: "1.9.0"},
      "node_modules/dep-a": {version: $a}} + $x)}'
}
lock 1.0.0 2.0.0 '{"node_modules/dep-b": {"version": "3.0.0"}}' \
  >"$seed/src/demo/npm/package-lock.json"
git -C "$seed" add -A
git -C "$seed" -c user.name=t -c user.email=t@t commit -qm seed
git clone -q --bare "$seed" "$origin"
run=$root/run
git clone -q "$origin" "$run"

# Pushes a branch off main with one commit, as Dependabot or as someone else,
# and lists it as an open PR by user (dependabot[bot] by default). The commit
# is whatever edit leaves in the clone.
pr_n=0
dependabot='49699333+dependabot[bot]@users.noreply.github.com'
open_pr() { # branch edit [author-email [pr-user]]
  local branch=$1 edit=$2 email=${3:-$dependabot}
  local user=${4:-dependabot[bot]} clone=$root/clone-$pr_n head
  git clone -q "$origin" "$clone"
  git -C "$clone" checkout -q -b "$branch"
  (cd "$clone" && "$edit")
  git -C "$clone" add -A
  git -C "$clone" -c user.name=x -c user.email="$email" commit -qm "$branch"
  git -C "$clone" push -q origin "$branch"
  head=$(git -C "$clone" rev-parse HEAD)
  pr_n=$((pr_n + 1))
  jq --argjson n "$pr_n" --arg r "$branch" --arg s "$head" --arg u "$user" \
    '. + [{number: $n, user: {login: $u},
      head: {ref: $r, sha: $s, repo: {full_name: "example/repo"}}}]' \
    "$PRS" >"$PRS.tmp" && mv "$PRS.tmp" "$PRS"
}

export GHCR_TAGS=demo@1.0.0
with_registry "$run"

# The published versions come from the stub registry, as the workflow's
# published job gives them.
bump() {
  (cd "$run" \
    && PUBLISHED_VERSIONS=$("$scripts/published-versions.sh") \
    && PATH=$root/bin:$PATH GH_TOKEN=token APP_SLUG=pinbot \
      GITHUB_REPOSITORY=example/repo PUBLISHED_VERSIONS=$PUBLISHED_VERSIONS \
      "$scripts/dependabot-bumps.sh")
}
show() { git -C "$origin" show "$1"; } # rev:path
head_of() { git -C "$origin" rev-parse "$1"; }
# Runs the release checks against a branch, as its PR's CI would.
release_checks() { # branch
  local clone=$root/check
  rm -rf "$clone"
  git clone -q -b "$1" "$origin" "$clone"
  with_registry "$clone"
  (cd "$clone" && "$scripts/check-versions.sh" "$(git rev-parse origin/main)")
}

# A version update: the tool moves a minor, one copy of dep-a a patch, dep-b
# goes and dep-c comes.
version_update() {
  echo '{"dependencies": {"demo-tool": "1.2.0"}}' >src/demo/npm/package.json
  lock 1.2.0 2.0.1 '{"node_modules/dep-c": {"version": "0.1.0"}}' \
    >src/demo/npm/package-lock.json
}
# A security update to a transitive package alone.
lock_patch() {
  lock 1.0.0 2.0.1 '{"node_modules/dep-b": {"version": "3.0.0"}}' \
    >src/demo/npm/package-lock.json
}
# An update that also touches a file the script doesn't release.
beyond_npm() {
  lock_patch
  echo 'echo changed' >src/demo/install.sh
}

up=dependabot/npm_and_yarn/src/demo/npm/demo-tool-1.2.0
open_pr "$up" version_update
up_head=$(head_of "$up")
patch=dependabot/npm_and_yarn/src/demo/npm/dep-a-2.0.1
open_pr "$patch" lock_patch
hand=dependabot/npm_and_yarn/src/demo/npm/hand
open_pr "$hand" lock_patch me@example.com
beyond=dependabot/npm_and_yarn/src/demo/npm/beyond
open_pr "$beyond" beyond_npm
outside=dependabot/github_actions/checkout
open_pr "$outside" lock_patch
mine=feature/src/mine
open_pr "$mine" lock_patch me@example.com someone

out=$(bump 2>&1)
rc=$?
expect "a PR it can't release fails the run" 0 "" test "$rc" = 1
expect "naming it" 0 "::error::#4" echo "$out"
expect "after the others had their turn" 0 "#1: finished" echo "$out"

# The version update.
expect "the commit goes on Dependabot's" 0 "" \
  test "$(head_of "$up^")" = "$up_head"
expect "as the App" 0 "42+pinbot[bot]@users.noreply.github.com" \
  git -C "$origin" log -1 --format=%ae "$up"
expect "letting Dependabot rebase over it" 0 "[dependabot skip]" \
  git -C "$origin" log -1 --format=%s "$up"
expect "a minor move raises a minor" 0 '"version": "1.1.0"' \
  show "$up:src/demo/devcontainer-feature.json"
expect "the entry lists the tool" 0 "- \`demo-tool\`: 1.0.0 → 1.2.0" \
  show "$up:src/demo/CHANGELOG.md"
expect "then the lock's moves, every copy of a name" 0 \
  "$(printf -- '- npm lock:\n  - dep-a: 1.9.0/2.0.0 → 1.9.0/2.0.1')" \
  show "$up:src/demo/CHANGELOG.md"
expect "a package gone" 0 "  - dep-b: removed" show "$up:src/demo/CHANGELOG.md"
expect "a package added" 0 "  - dep-c: added 0.1.0" \
  show "$up:src/demo/CHANGELOG.md"
expect_not "and not the tool twice" "  - demo-tool" \
  show "$up:src/demo/CHANGELOG.md"
expect "under its version" 0 "$(printf '## 1.1.0\n\n- %s' "\`demo-tool\`")" \
  show "$up:src/demo/CHANGELOG.md"
expect "and passes the version check" 0 "" release_checks "$up"

# The lock-only update.
expect "a lock's patch moves raise a patch" 0 '"version": "1.0.1"' \
  show "$patch:src/demo/devcontainer-feature.json"
expect "its entry is the lock's" 0 \
  "$(printf -- '## 1.0.1\n\n- npm lock:\n  - dep-a:')" \
  show "$patch:src/demo/CHANGELOG.md"
expect "and passes the version check" 0 "" release_checks "$patch"

# What it leaves.
expect "a branch someone else committed to is left" 0 \
  "#3: has commits by others" echo "$out"
expect "as it was" 0 "" test "$(git -C "$origin" log -1 --format=%ae "$hand")" \
  = me@example.com
expect "a PR beyond the npm files is left" 0 "" \
  test "$(git -C "$origin" log -1 --format=%s "$beyond")" = "$beyond"
expect_not "Dependabot outside src/ isn't looked at" "#5" echo "$out"
expect_not "nor anyone else's PR under src/" "#6" echo "$out"
expect "neither is touched" 0 "" test \
  "$(git -C "$origin" log -1 --format=%s "$outside")" = "$outside"

# A second run changes nothing, and fails again for PR 4, still open.
up_done=$(head_of "$up")
expect "a finished PR is left on the next run" 1 "#1: already finished" bump
expect "with its head" 0 "" test "$(head_of "$up")" = "$up_done"

# Dependabot rebasing drops the commit, so the next run makes it again.
git -C "$origin" update-ref "refs/heads/$up" "$up_head"
bump >/dev/null 2>&1
expect "a rebased PR is finished again" 0 "" \
  test "$(head_of "$up^")" = "$up_head"

# A push landing between the script's fetch and its own loses nothing: the
# lease refuses the script's.
race=dependabot/npm_and_yarn/src/demo/npm/race
open_pr "$race" lock_patch
racer=$root/racer
git clone -q -b "$race" "$origin" "$racer"
echo '{"dependencies": {"demo-tool": "1.0.1"}}' \
  >"$racer/src/demo/npm/package.json"
git -C "$racer" -c user.name=x -c user.email="$dependabot" commit -qam again
export RACE=$root/race-flag RACER=$racer RACE_PR=7
touch "$RACE"
expect "a push racing Dependabot's is refused" 1 "#7: push refused" bump
expect "and Dependabot's stands" 0 "" \
  test "$(head_of "$race")" = "$(git -C "$racer" rev-parse HEAD)"

# A finished PR whose version has since been published is finished again,
# above it.
up_done=$(head_of "$up")
export GHCR_TAGS="demo@1.0.0 demo@1.1.0"
bump >/dev/null 2>&1
expect "a PR whose version got published is finished again" 0 "" \
  test "$(head_of "$up^")" = "$up_head"
expect "replacing the App's commit" 0 "" test "$(head_of "$up")" != "$up_done"
expect "above the published version" 0 '"version": "1.2.0"' \
  show "$up:src/demo/devcontainer-feature.json"
expect "with an entry of its own" 0 \
  "$(printf '## 1.2.0\n\n- %s' "\`demo-tool\`")" \
  show "$up:src/demo/CHANGELOG.md"
expect "and passes the version check" 0 "" release_checks "$up"
up_done=$(head_of "$up")
expect "a PR finished above the published version is left" 1 \
  "#1: already finished" bump
expect "with its head" 0 "" test "$(head_of "$up")" = "$up_done"

# A PR on a main whose version is unpublished rides it.
set_json=$seed/src/demo/devcontainer-feature.json
jq '.version = "1.3.0"' "$set_json" >"$set_json.tmp" \
  && mv "$set_json.tmp" "$set_json"
printf '## 1.3.0\n\n- Earlier.\n\n## 1.0.0\n\n- First release.\n' \
  >"$seed/src/demo/CHANGELOG.md"
git -C "$seed" -c user.name=t -c user.email=t@t commit -qam "demo 1.3.0"
git -C "$seed" push -q "$origin" HEAD:main
ridden=dependabot/npm_and_yarn/src/demo/npm/ride
open_pr "$ridden" lock_patch
out=$(bump 2>&1)
expect "a PR under an unpublished version rides it" 0 \
  "finished, as demo 1.3.0" echo "$out"
expect "keeping the version" 0 '"version": "1.3.0"' \
  show "$ridden:src/demo/devcontainer-feature.json"
expect "adding its lines to that version's entry" 0 \
  "$(printf '## 1.3.0\n\n- Earlier.\n- npm lock:\n  - dep-a:')" \
  show "$ridden:src/demo/CHANGELOG.md"
expect "and passes the version check" 0 "" release_checks "$ridden"

# A run whose lookup fails leaves a finished PR alone, so the outage can't
# undo its ride.
ridden_done=$(head_of "$ridden")
bump_down() { GHCR_DOWN=demo bump; }
# PR 4 still fails the run.
expect "a failed lookup leaves a finished PR" 1 \
  "with no published version to check it against" bump_down
expect "with its head" 0 "" test "$(head_of "$ridden")" = "$ridden_done"

# A PR finished while the lookup failed raises main's version, leaving the
# unpublished entry behind; the next run that can look it up rides instead.
fallback=dependabot/npm_and_yarn/src/demo/npm/fallback
open_pr "$fallback" lock_patch
out=$(bump_down 2>&1)
expect "a PR finished during a failed lookup raises main's version" 0 \
  "finished, as demo 1.3.1" echo "$out"
expect "which the version check fails" 1 \
  "1.3.0 was never published, so fold its '## 1.3.0' entry" \
  release_checks "$fallback"
out=$(bump 2>&1)
expect "the next run finishes it again" 0 "#9: finished again, as demo 1.3.0" \
  echo "$out"
expect "riding main's version" 0 '"version": "1.3.0"' \
  show "$fallback:src/demo/devcontainer-feature.json"
expect "and passing the version check" 0 "" release_checks "$fallback"
expect "while a PR whose rebuild matches is left" 0 "#8: already finished" \
  echo "$out"
expect "with its head" 0 "" test "$(head_of "$ridden")" = "$ridden_done"

summary
