#!/bin/bash
# shellcheck source-path=SCRIPTDIR
# Tests release-pr.sh offline, against a local bare remote, a stub gh that
# keeps pull requests in a file, and the stub registry.
set -uo pipefail
scripts=$(cd "$(dirname "$0")" && pwd)
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
# shellcheck source=test_lib.sh
. "$scripts/test_lib.sh"

# The stub gh serves PRs from $PRS newest first (so the script must sort
# them), insists on the owner-qualified head query and a main base, and reads
# a PR's commit authors from the remote's branch as GitHub would.
origin=$root/origin.git
export ORIGIN=$origin PRS=$root/prs.json
mkdir -p "$root/bin"
cat >"$root/bin/gh" <<'STUB'
#!/bin/bash
shift
method=GET path='' filter='' input=''
while [ "$#" -gt 0 ]; do
  case $1 in
    -X) method=$2 && shift ;;
    --input) input=$2 && shift ;;
    --jq) filter=$2 && shift ;;
    --paginate) ;;
    *) path=$1 ;;
  esac
  shift
done
out() { if [ -n "$filter" ]; then jq -r "$filter"; else cat; fi; }
pulls=repos/example/repo/pulls
case "$method $path" in
  "GET users/"*) echo '{"id": 42}' | out ;;
  "GET $pulls?head=example:release&state=all&per_page=100")
    jq reverse "$PRS" | out
    ;;
  "POST $pulls")
    jq -e '.base == "main" and .head == "release"' "$input" >/dev/null \
      || { echo "stub gh: bad PR $(cat "$input")" >&2 && exit 1; }
    n=$(($(jq length "$PRS") + 1))
    jq --argjson n "$n" --slurpfile r "$input" '. + [$r[0] + {number: $n,
      state: "open", merged_at: null,
      created_at: "2026-10-0\($n)T00:00:00Z"}]' \
      "$PRS" >"$PRS.tmp" && mv "$PRS.tmp" "$PRS"
    echo "{\"number\": $n}" | out
    ;;
  "GET $pulls/"*/commits*)
    [ -z "${COMMITS_DOWN:-}" ] || { echo "stub gh: HTTP 502" >&2 && exit 1; }
    git -C "$ORIGIN" log --format=%ae main..release \
      | sed 's/^42+pinbot\[bot\]@.*/pinbot[bot]/; t; s/.*/someone/' \
      | jq -R '{author: {login: .}}' | jq -s . | out
    ;;
  "PATCH $pulls/"*)
    n=${path##*/}
    jq --argjson n "$n" --slurpfile r "$input" \
      'map(if .number == $n then . + $r[0] else . end)' "$PRS" >"$PRS.tmp" \
      && mv "$PRS.tmp" "$PRS"
    echo "{\"number\": $n}" | out
    ;;
  *) echo "stub gh: unexpected $method $path" >&2 && exit 1 ;;
esac
STUB
chmod +x "$root/bin/gh"
echo '[]' >"$PRS"

# Two published Features, each tagged at the seed, and one never published.
seed=$root/seed
git init -q -b main "$seed"
feature() { # id version
  mkdir -p "$seed/src/$1"
  printf '{\n  "id": "%s",\n  "version": "%s"\n}\n' "$1" "$2" \
    >"$seed/src/$1/devcontainer-feature.json"
  printf '## %s\n\n- First release.\n' "$2" >"$seed/src/$1/CHANGELOG.md"
  echo 'echo hi' >"$seed/src/$1/install.sh"
}
feature alpha 1.0.0
feature beta 2.0.0
feature gamma 1.0.0
commit() { # message
  git -C "$seed" add -A
  git -C "$seed" -c user.name=t -c user.email=t@t commit -qm "$1"
}
commit seed
git -C "$seed" tag feature_alpha_1.0.0
git -C "$seed" tag feature_beta_2.0.0
git clone -q --bare "$seed" "$origin"
git -C "$seed" remote add origin "$origin"
push() { git -C "$seed" push -q origin main; }
run=$root/run
git clone -q "$origin" "$run"
with_registry "$run"
export GHCR_TAGS="alpha@1.0.0 beta@2.0.0"

# Adds a line under "## Unreleased" (and a subheading), in a fresh section
# when there's none.
unreleased() { # id line [subheading]
  local log=$seed/src/$1/CHANGELOG.md
  if ! grep -qx '## Unreleased' "$log"; then
    printf '## Unreleased\n\n%s' "$(cat "$log")" >"$log"
  fi
  awk -v line="$2" -v heading="${3:-}" '
    { print }
    $0 == "## Unreleased" && !done {
      print ""
      if (heading != "") { print "### " heading; print "" }
      print line
      done = 1
    }' "$log" >"$log.tmp" && mv "$log.tmp" "$log"
}

# The published versions come from the stub registry, as the workflow's
# published job gives them. The report starts empty, as pin-bumps.sh leaves
# it for the release step.
release() {
  : >"$root/report"
  (cd "$run" \
    && PUBLISHED_VERSIONS=$("$scripts/published-versions.sh" 2>/dev/null) \
    && PATH=$root/bin:$PATH GH_TOKEN=token APP_SLUG=pinbot \
      GITHUB_REPOSITORY=example/repo PUBLISHED_VERSIONS=$PUBLISHED_VERSIONS \
      "$scripts/release-pr.sh" --report "$root/report")
}
on_branch() { git -C "$origin" show "release:src/$1"; }
pr() { jq -r ".[] | select(.number == $1) | .$2" "$PRS"; }
pr_count() { jq length "$PRS"; }
branch_tip() { git -C "$origin" rev-parse -q --verify release; }
parent_is() { # rev
  test "$(git -C "$origin" rev-parse release^)" \
    = "$(git -C "$origin" rev-parse "$1")"
}
tab=$'\t'

# --- Nothing to release -------------------------------------------------------

expect "a main with nothing changed opens no PR" 0 \
  "alpha: nothing to release since feature_alpha_1.0.0" release
expect "and pushes no branch" 1 "" branch_tip
expect "a never-published Feature is left out" 0 \
  "gamma: never published, so left out" release
expect "reporting each Feature ok" 0 "release${tab}beta${tab}ok" \
  cat "$root/report"
expect "and the release push" 0 "release-push${tab}release${tab}ok" \
  cat "$root/report"

echo "Docs." >>"$seed/src/alpha/README.md"
unreleased alpha "- A docs fix."
commit "docs(alpha): a docs fix"
push
expect "a docs-only change opens no PR" 0 "alpha: nothing to release" release
expect "nor does it count for its Feature" 0 0 pr_count

# --- Opening the PR -----------------------------------------------------------

echo 'echo fixed' >"$seed/src/alpha/install.sh"
unreleased alpha "- Fix."
commit "fix(alpha): a fix"
push
expect "a code change opens the release PR" 0 "release: opened #1" release
expect "titled with the release" 0 "chore: release alpha 1.0.1" pr 1 title
expect "with its table row" 0 "| \`alpha\` | 1.0.0 | 1.0.1 | patch |" \
  pr 1 body
expect "saying how to act on it" 0 "push a commit here" pr 1 body
expect "on main" 0 "" parent_is main
expect "the branch sets the version" 0 '"version": "1.0.1"' \
  on_branch alpha/devcontainer-feature.json
expect "and writes its entry from Unreleased, docs line included" 0 "" \
  holds "$(on_branch alpha/CHANGELOG.md)" \
  "$(printf '## 1.0.1\n\n- Fix.\n- A docs fix.\n\n## 1.0.0')"
expect_not "leaving no Unreleased section" "## Unreleased" \
  on_branch alpha/CHANGELOG.md
expect_not "and leaves beta alone" "beta" pr 1 title
expect "committed as the App" 0 "42+pinbot[bot]@users.noreply.github.com" \
  git -C "$origin" log -1 --format=%ae release
check=$root/check
git clone -q -b release "$origin" "$check"
expect "the branch passes the bump's changelog check" 0 "" \
  bash -c "cd '$check' && '$scripts/check-changelog.sh' --bump alpha"

tip=$(branch_tip)
expect "a second run changes nothing" 0 "release: release unchanged" release
expect "keeping the branch" 0 "" test "$(branch_tip)" = "$tip"
expect "and the PR" 0 1 pr_count

mkdir -p "$seed/.github"
echo 'on: push' >"$seed/.github/ci.yml"
commit "ci: a workflow change"
push
expect "a change outside src keeps the branch's parent" 0 \
  "release: release unchanged" release
expect "so a workflow change needs no push" 0 "" test "$(branch_tip)" = "$tip"

# --- Rebuilding ---------------------------------------------------------------

unreleased alpha "- A feature." Minor
echo 'echo more' >>"$seed/src/alpha/install.sh"
commit "feat(alpha): a feature"
push
expect "a newer change rebuilds the PR" 0 "release: updated #1" release
expect "on the new main" 0 "" parent_is main
expect "at its level" 0 "chore: release alpha 1.1.0" pr 1 title
expect "with the subheading dropped" 0 "" \
  holds "$(on_branch alpha/CHANGELOG.md)" \
  "$(printf '## 1.1.0\n\n- A feature.\n- Fix.\n- A docs fix.\n\n## 1.0.0')"

echo 'echo beta' >"$seed/src/beta/install.sh"
commit "fix(beta): no changelog line"
push
expect "a change with no Unreleased line fails the run" 1 \
  "::error::beta: src/beta changed since feature_beta_2.0.0, but its" release
expect "reporting it" 0 "release${tab}beta${tab}fail${tab}src/beta changed" \
  cat "$root/report"
expect "still releasing the others" 0 "chore: release alpha 1.1.0" \
  pr 1 title
unreleased beta "- A change." Major
commit "docs(beta): its line"
push
release >/dev/null 2>&1
expect "a line under ### Major raises the major" 0 \
  "chore: release alpha 1.1.0, beta 3.0.0" pr 1 title

# --- Leaving Features out -----------------------------------------------------

release_down() { GHCR_DOWN=alpha release; }
expect "a failed lookup of a published Feature fails" 1 \
  "::error::alpha: its GHCR lookup failed" release_down
expect "reporting it" 0 "release${tab}alpha${tab}fail${tab}its GHCR lookup" \
  cat "$root/report"
expect "leaving it out of the PR" 0 "chore: release beta 3.0.0" pr 1 title
release >/dev/null 2>&1

git -C "$origin" tag -d feature_beta_2.0.0 >/dev/null
git -C "$run" tag -d feature_beta_2.0.0 >/dev/null
expect "a missing release tag fails" 1 "no tag feature_beta_2.0.0" release
expect "reporting it" 0 "release${tab}beta${tab}fail${tab}there's no tag" \
  cat "$root/report"
git -C "$seed" push -q origin feature_beta_2.0.0
release >/dev/null 2>&1

mkdir -p "$seed/src/delta"
echo '{' >"$seed/src/delta/devcontainer-feature.json"
commit "a Feature whose release can't be worked out"
push
expect "a Feature whose release can't be worked out fails the run" 1 \
  "::error::delta: its release couldn't be worked out" release
expect "while the others still have their turn" 0 \
  "release${tab}gamma${tab}ok" cat "$root/report"
expect "and the PR is still kept" 0 "release-push${tab}release${tab}ok" \
  cat "$root/report"
git -C "$seed" rm -rq src/delta
commit "remove delta"
push
release >/dev/null 2>&1

# As after a failed published job.
release_blind() {
  (cd "$run" && PATH=$root/bin:$PATH GH_TOKEN=token APP_SLUG=pinbot \
    GITHUB_REPOSITORY=example/repo PUBLISHED_VERSIONS='' \
    "$scripts/release-pr.sh")
}
expect "with no published versions, the run fails" 1 \
  "no published versions to release against" release_blind
expect "changing nothing" 0 "chore: release alpha 1.1.0, beta 3.0.0" \
  pr 1 title

# --- Hand edits, a refused push, closing --------------------------------------

hand=$root/hand
git clone -q -b release "$origin" "$hand"
echo '- Reworded.' >>"$hand/src/alpha/CHANGELOG.md"
git -C "$hand" -c user.name=me -c user.email=me@x commit -qam "reword"
git -C "$hand" push -q origin HEAD:release
tip=$(branch_tip)
expect "a hand-edited PR is left as it is" 0 \
  "release: #1 has commits the workflow didn't make" release
expect "branch included" 0 "" test "$(branch_tip)" = "$tip"
# Both main versions behind what's published: nothing to release.
release_ahead() { GHCR_TAGS="alpha@1.1.0 beta@3.0.0" release; }
expect "even with nothing to release" 0 "release: #1 has commits" release_ahead
expect "it stays open" 0 open pr 1 state
jq 'map(.state = "closed")' "$PRS" >"$PRS.tmp" && mv "$PRS.tmp" "$PRS"
expect "once it's closed, the next run rebuilds it" 0 "release: opened #2" \
  release
expect_not "without the hand edit" "Reworded" on_branch alpha/CHANGELOG.md
release_blind_authors() { COMMITS_DOWN=1 release; }
tip=$(branch_tip)
expect "a failed author lookup fails the run" 1 "stub gh: HTTP 502" \
  release_blind_authors
expect_not "with no ok row for the release push" \
  "release-push${tab}release${tab}ok" cat "$root/report"
expect "leaving the branch" 0 "" test "$(branch_tip)" = "$tip"

unreleased alpha "- Another."
echo 'echo again' >>"$seed/src/alpha/install.sh"
commit "fix(alpha): another"
push
cat >"$origin/hooks/pre-receive" <<'EOF'
#!/bin/sh
echo "refusing to allow a GitHub App to update workflows" >&2
exit 1
EOF
chmod +x "$origin/hooks/pre-receive"
expect "a refused push fails the run" 1 "release: push refused: remote:" \
  release
expect "reporting it" 0 "release-push${tab}release${tab}refused" \
  cat "$root/report"
expect_not "and no ok row for it" "release-push${tab}release${tab}ok" \
  cat "$root/report"
rm "$origin/hooks/pre-receive"
release >/dev/null 2>&1

git -C "$seed" checkout -q feature_alpha_1.0.0 -- src/alpha/install.sh
git -C "$seed" checkout -q feature_beta_2.0.0 -- src/beta/install.sh
commit "revert the code changes"
push
expect "with nothing left to release, the PR closes" 0 \
  "release: closed #2, nothing to release" release
expect "as GitHub shows it" 0 closed pr 2 state

# --- After a release merges ---------------------------------------------------

feature_json=$seed/src/alpha/devcontainer-feature.json
jq '.version = "1.0.1"' "$feature_json" >"$feature_json.tmp" \
  && mv "$feature_json.tmp" "$feature_json"
echo 'echo released' >"$seed/src/alpha/install.sh"
commit "chore: release alpha 1.0.1"
push
expect "a Feature whose main version awaits publishing is left out" 0 \
  "alpha: main's 1.0.1 isn't published yet, so left out" release

summary
