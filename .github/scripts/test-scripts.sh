#!/bin/bash
# shellcheck source-path=SCRIPTDIR
# Tests the CI scripts in .github/scripts, and lib/fetch_verified.sh, against
# throwaway git repos built from this checkout, with stub devcontainer,
# docker and curl CLIs. Prints one line per case and exits non-zero if any
# fails.
set -uo pipefail
repo=$(cd "$(dirname "$0")/../.." && pwd)
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
# shellcheck source=test_lib.sh
. "$repo/.github/scripts/test_lib.sh"

# A repo whose base commit copies src/, test/ and the scripts, with the stub
# registry listing every Feature as published at its version; the change
# commit follows. Leaves the shell in it, with $base set.
new_repo() {
  cd "$(mktemp -d "$root/repo.XXXX")" || exit 1
  git init -q
  git config user.email test@example.com
  git config user.name test
  cp -R "$repo/src" "$repo/test" .
  mkdir -p .github lib && cp -R "$repo/.github/scripts" .github/
  echo x >lib/keep
  # The cases name gh-config's and grimoire's versions, so they're fixed here,
  # where a release can't move them.
  set_version gh-config 1.0.0
  printf '## 1.0.0\n\n- First release.\n' >src/gh-config/CHANGELOG.md
  set_version grimoire 1.0.1
  printf '## 1.0.1\n\n- A fix.\n\n## 1.0.0\n\n- First release.\n' \
    >src/grimoire/CHANGELOG.md
  with_registry
  GHCR_TAGS=$(jq -r '"\(.id)@\(.version)"' src/*/devcontainer-feature.json)
  export GHCR_TAGS
  git add -A && git commit -qm base
  base=$(git rev-parse HEAD)
}
commit() { git add -A && git commit -qm change --allow-empty; }
set_version() { # id version
  local json=src/$1/devcontainer-feature.json
  jq --arg v "$2" '.version = $v' "$json" >"$json.tmp" \
    && mv "$json.tmp" "$json"
}
prepend_changelog() { # id text
  local log=src/$1/CHANGELOG.md
  printf '%b' "$2" | cat - "$log" >"$log.tmp" && mv "$log.tmp" "$log"
}
versions() { .github/scripts/check-versions.sh "$base"; }

# --- check-versions.sh and check-changelog.sh ---

new_repo
echo '# edit' >>src/gh-config/install.sh
commit
expect "a change without an Unreleased line fails" 1 \
  "src/gh-config changed, so add its line under '## Unreleased'" versions
prepend_changelog gh-config '## Unreleased\n\n- Fix.\n\n'
git add -A && git commit -q --amend --no-edit
expect "a change with its Unreleased line passes" 0 "" versions

new_repo
echo '# edit' >>src/gh-config/install.sh
prepend_changelog gh-config '## Unreleased\n\n\n'
commit
expect "a blank Unreleased line doesn't count" 1 "add its line under" \
  versions

new_repo
prepend_changelog gh-config '## Unreleased\n\n- Earlier.\n\n'
git add -A && git commit -qm earlier
base=$(git rev-parse HEAD)
echo '# edit' >>src/gh-config/install.sh
commit
expect "nor does a line already there" 1 "add its line under" versions
sed -i '/^- Earlier\.$/d' src/gh-config/CHANGELOG.md
git add -A && git commit -q --amend --no-edit
expect "nor removing one" 1 "add its line under" versions

new_repo
echo '# edit' >>src/gh-config/install.sh
prepend_changelog gh-config '## Unreleased\n\n### Minor\n\n'
commit
expect "nor does a bare level subheading" 1 "add its line under" versions

new_repo
prepend_changelog gh-config '## Unreleased\n\n- Same.\n\n'
git add -A && git commit -qm earlier
base=$(git rev-parse HEAD)
echo '# edit' >>src/gh-config/install.sh
sed -i 's/^- Same\.$/- Same.\n- Same./' src/gh-config/CHANGELOG.md
commit
expect "a line repeating one already there counts" 0 "" versions

new_repo
set_version gh-config 0.9.0
commit
expect "a lower version fails" 1 \
  "rise above the published 1.0.0, or return to it, but it's 0.9.0" versions

new_repo
set_version gh-config 1.0.0.1
prepend_changelog gh-config '## 1.0.0.1\n\n- Fix.\n\n'
commit
expect "a version that isn't X.Y.Z fails" 1 "must be X.Y.Z" versions

new_repo
set_version gh-config 1.0.1
commit
expect "a release without an entry fails" 1 "no '## 1.0.1' entry" versions

new_repo
set_version gh-config 1.0.1
prepend_changelog gh-config '## Unreleased\n\n- Doc.\n\n## 1.0.1\n\n- Fix.\n\n'
commit
expect "a line left under Unreleased fails a release" 1 \
  "'## Unreleased' still has entries" versions

new_repo
set_version gh-config 1.0.1
prepend_changelog gh-config '## Unreleased\n\n## 1.0.1\n\n- Fix.\n\n'
commit
expect_not "a release with its entry passes" "::" versions

new_repo
set_version gh-config 1.0.1
prepend_changelog gh-config '## 1.0.1\n\n- Fix.\n\n'
prepend_changelog gh-config '## Unreleased\n\n### Minor\n\n'
commit
expect "a bare level subheading left under Unreleased passes a release" 0 "" \
  versions

new_repo
set_version gh-config 1.0.1
prepend_changelog gh-config '## 1.0.1\n\n### Minor\n\n'
commit
expect "an entry of only a level subheading is empty" 1 \
  "the '## 1.0.1' entry is empty" versions

new_repo
for f in README.md NOTES.md CHANGELOG.md; do
  echo x >>"src/gh-config/$f"
done
commit
expect "a README, NOTES or CHANGELOG change alone passes" 0 "" versions

new_repo
mkdir src/new-id
jq '.id = "new-id" | .version = "1.0.0"' \
  src/gh-config/devcontainer-feature.json >src/new-id/devcontainer-feature.json
echo 'echo hi' >src/new-id/install.sh
commit
expect "a new Feature without a changelog fails" 1 \
  "src/new-id has no CHANGELOG.md" versions
printf '## 1.0.0\n\n- First release.\n' >src/new-id/CHANGELOG.md
git add -A && git commit -q --amend --no-edit
expect "a new Feature with its changelog passes" 0 "" versions

new_repo
git rm -rq src/gh-config
commit
expect "a deleted Feature passes" 0 "" versions

new_repo
git mv src/gh-config/record_failure.sh lib/record_failure.sh
commit
expect "a file moved out to lib/ fails its Feature" 1 "src/gh-config changed" \
  versions

# Both ends sit under src/, so only --no-renames keeps the source listed.
new_repo
git mv src/gh-config/install.sh src/grimoire/moved.sh
prepend_changelog grimoire '## Unreleased\n\n- Moved.\n\n'
commit
expect "a file moved into a Feature fails the one it left" 1 \
  "src/gh-config changed" versions
if ! versions 2>&1 | grep -q grimoire; then
  pass "and passes the one it joined"
else
  fail "and passes the one it joined" "$(versions 2>&1)"
fi

new_repo
set_version gh-config 1.0.1
prepend_changelog gh-config '## 1.0.10\n\n- Other.\n\n'
expect "## 1.0.10 doesn't count as ## 1.0.1" 1 "no '## 1.0.1' entry" \
  .github/scripts/check-changelog.sh --bump gh-config

new_repo
set_version gh-config 1.0.1
prepend_changelog gh-config '## 1.0.1\n\n### Fixed\n\n- Fix.\n\n'
commit
expect "an entry with a ### subsection passes" 0 "" versions

new_repo
set_version gh-config 1.0.1
prepend_changelog gh-config '## 1.0.1\n\n'
commit
expect "an empty entry fails" 1 "the '## 1.0.1' entry is empty" versions

new_repo
set_version gh-config 1.0.1
expect "--release fails without the entry" 1 "no '## 1.0.1' entry" \
  .github/scripts/check-changelog.sh --release gh-config
prepend_changelog gh-config '## Unreleased\n\n- Doc.\n\n## 1.0.1\n\n- Fix.\n\n'
expect "--release ignores Unreleased" 0 "" \
  .github/scripts/check-changelog.sh --release gh-config

new_repo
release_all() {
  local id ids
  # shellcheck source=feature_ids.sh
  . .github/scripts/feature_ids.sh
  ids=$(feature_ids)
  [ -n "$ids" ] || return 1
  for id in $ids; do
    .github/scripts/check-changelog.sh --release "$id" || return 1
  done
}
expect "every Feature's changelog passes --release" 0 "" release_all
expect "check-changelog.sh rejects a bad mode" 2 "usage" \
  .github/scripts/check-changelog.sh --foo gh-config
expect "check-versions.sh needs a base" 2 "usage" \
  .github/scripts/check-versions.sh

# --- check-root-changelog.sh ---

# A repo whose base already keeps the root changelog.
log_repo() {
  new_repo
  printf '# Changelog\n\n## 2026-10\n\n- Earlier.\n' >CHANGELOG.md
  git add -A && git commit -qm log
  base=$(git rev-parse HEAD)
}
root_log() { .github/scripts/check-root-changelog.sh "$base"; }

log_repo
cp -R src/gh-config src/new-one
commit
expect "a Feature added without a root changelog line fails" 1 \
  "::error file=CHANGELOG.md::src/new-one was added;" root_log
printf '\n## 2026-11\n' >>CHANGELOG.md
git add -A && git commit -q --amend --no-edit
expect "a heading alone doesn't count" 1 "src/new-one was added" root_log
sed -i 's/^- Earlier\.$/- Earlier, reworded./' CHANGELOG.md
git add -A && git commit -q --amend --no-edit
expect "nor a new line that doesn't name it" 1 "src/new-one was added" \
  root_log
printf '\n- The new-one Feature.\n' >>CHANGELOG.md
git add -A && git commit -q --amend --no-edit
expect "a Feature added with its line passes" 0 "" root_log

log_repo
git rm -rq src/gh-config
commit
expect "a Feature removed without a line fails" 1 "src/gh-config was removed" \
  root_log

log_repo
git mv src/gh-config src/renamed
printf '\n- The renamed Feature.\n' >>CHANGELOG.md
commit
expect "a rename's line names the old id too" 1 "src/gh-config was removed" \
  root_log
if ! root_log 2>&1 | grep -q src/renamed; then
  pass "and passes the new one"
else
  fail "and passes the new one" "$(root_log 2>&1)"
fi
sed -i 's/^- The renamed Feature\.$/- gh-config is now renamed./' CHANGELOG.md
git add -A && git commit -q --amend --no-edit
expect "a rename whose line names both passes" 0 "" root_log

new_repo
cp -R src/gh-config src/new-one
printf '# Changelog\n\n## 2026-10\n\n- The new-one Feature.\n' >CHANGELOG.md
commit
expect "a base without the changelog passes with the new line" 0 "" root_log

log_repo
echo '# edit' >>src/gh-config/install.sh
set_version gh-config 1.1.0
commit
expect "a change to a Feature, its version included, needs no line" 0 "" \
  root_log

# --- check-versions.sh against GHCR, and published-versions.sh ---

# A release of gh-config 1.1.0, checked against the given registry.
release_against() { # GHCR_TAGS [GHCR_DOWN]
  new_repo
  set_version gh-config 1.1.0
  prepend_changelog gh-config '## 1.1.0\n\n- Change.\n\n'
  commit
  GHCR_TAGS=$1 GHCR_DOWN=${2:-} versions
}
expect "a release not above the highest published version fails" 1 \
  "rise above the published 1.2.0, or return to it, but it's 1.1.0" \
  release_against "gh-config@1.0.0 gh-config@1.2.0"
expect "a release fails when the lookup does" 1 \
  "GHCR couldn't tell its published version (503 from ghcr.io for gh-config)" \
  release_against '' gh-config
expect "and for a Feature never published" 1 \
  "couldn't tell its published version (403: access to gh-config" \
  release_against ''
garbled_release() { GHCR_GARBLED=gh-config release_against gh-config@1.0.0; }
expect "GHCR output that can't be parsed fails as a failed lookup" 1 \
  "couldn't tell its published version" garbled_release
garbled_has() {
  (. .github/scripts/ghcr_lib.sh \
    && GHCR_GARBLED=grimoire ghcr_has grimoire 1.0.1)
}
expect "and ghcr_has reads it as one" 2 "" garbled_has

new_repo
expect "--report passes with every version on GHCR" 0 "" \
  .github/scripts/check-pending.sh --report

# grimoire's 1.0.1 entry, with only 1.0.0 published: a version never shipped.
new_repo
set_version grimoire 1.1.0
prepend_changelog grimoire '## 1.1.0\n\n- Change.\n\n'
commit
expect "a release leaving an unpublished version's entry fails" 1 \
  "has entries for 1.0.1, never published; fold them into '## 1.1.0'" \
  env GHCR_TAGS=grimoire@1.0.0 .github/scripts/check-versions.sh "$base"
expect_not "leaving a published version's entry passes" "::" versions
sed -i '/^## 1\.0\.1$/,+1d' src/grimoire/CHANGELOG.md
git add -A && git commit -q --amend --no-edit
expect "an entry folded into the new one passes" 0 "" \
  env GHCR_TAGS=grimoire@1.0.0 .github/scripts/check-versions.sh "$base"

new_repo
set_version grimoire 1.0.0
commit
expect "a return to the published version leaving its entry fails" 1 \
  "has entries for 1.0.1, never published" \
  env GHCR_TAGS=grimoire@1.0.0 .github/scripts/check-versions.sh "$base"
sed -i 's/^## 1\.0\.1$/## Unreleased/' src/grimoire/CHANGELOG.md
git add -A && git commit -q --amend --no-edit
expect "with its lines moved under Unreleased, it passes" 0 "" \
  env GHCR_TAGS=grimoire@1.0.0 .github/scripts/check-versions.sh "$base"
echo '# edit' >>src/grimoire/install.sh
git add -A && git commit -q --amend --no-edit
expect "but code changed with it needs its own line" 1 "add its line under" \
  env GHCR_TAGS=grimoire@1.0.0 .github/scripts/check-versions.sh "$base"

new_repo
published() {
  GHCR_TAGS="gh-config@1.0.0 gh-config@1.10.0 gh-config@1.9.2
    gh-config@2.0.0-rc.1 grimoire@1.0.1" GHCR_DOWN=liza \
    .github/scripts/published-versions.sh
}
expect "published-versions gives the highest X.Y.Z" 0 '"gh-config":"1.10.0"' \
  published
expect "of each published Feature" 0 '"grimoire":"1.0.1"' published
expect_not "leaving out a failed lookup" '"liza"' published
expect "warning of it" 0 "::warning::liza: the GHCR lookup failed" published
expect "with its cause" 0 "lookup failed: 503 from ghcr.io for liza" published
expect_not "and an unpublished Feature" '"claude-code"' published
garbled_published() {
  GHCR_GARBLED=grimoire .github/scripts/published-versions.sh
}
expect "GHCR output that can't be parsed warns as a failed lookup" 0 \
  "::warning::grimoire: the GHCR lookup failed" garbled_published
only_grimoire() {
  test "$(GHCR_TAGS=grimoire@1.0.1 .github/scripts/published-versions.sh)" \
    = '{"grimoire":"1.0.1"}'
}
expect "as one JSON object" 0 "" only_grimoire

# --- emit-features.sh ---

# Prints emit-features.sh's exit status and outputs for an event.
emit() { # event before
  local out
  out=$(mktemp)
  EVENT=$1 BEFORE=${2:-} GITHUB_OUTPUT=$out .github/scripts/emit-features.sh \
    >/dev/null 2>&1
  echo "rc=$?"
  cat "$out"
}
# A repo with an origin, so a push can fetch its before commit.
new_pushed_repo() { # path changed by the second commit
  local origin
  new_repo
  origin=$(mktemp -d "$root/origin.XXXX")
  git init -q --bare "$origin"
  git remote add origin "$origin"
  git push -q origin HEAD:main
  echo x >>"$1"
  commit
  git push -q origin HEAD:main
}
full='"id":"gh-config","runner":"ubuntu-24.04-arm"'

new_pushed_repo src/gh-config/install.sh
out=$(emit pull_request)
if grep -qF "$full" <<<"$out" && grep -qx "base=$base" <<<"$out"; then
  pass "a PR changing a Feature runs everything against its base"
else
  fail "PR, Feature change" "$out"
fi
out=$(emit push "$base")
if grep -qF "$full" <<<"$out" && grep -qx "base=$base" <<<"$out"; then
  pass "a push changing a Feature runs everything against before"
else
  fail "push, Feature change" "$out"
fi
out=$(emit push 0000000000000000000000000000000000000000)
if grep -qF "$full" <<<"$out" && grep -qx "base=" <<<"$out"; then
  pass "a push whose before can't be fetched runs everything"
else
  fail "push, no before" "$out"
fi
out=$(emit schedule)
if grep -qF "$full" <<<"$out" && grep -qx "base=" <<<"$out"; then
  pass "a scheduled run runs everything, with no base"
else
  fail "schedule" "$out"
fi
out=$(emit pull_request)
matrix_jq() { # filter
  sed -n 's/^matrix=//p' <<<"$out" | jq -c "$1"
}
want=$(jq -c '[keys[] as $s | ("ubuntu-24.04", "ubuntu-24.04-arm") as $r
  | {id: "_global", scenario: $s, runner: $r}] | sort' \
  test/_global/scenarios.json)
if [ "$(matrix_jq '[.[] | select(.id == "_global")] | sort')" = "$want" ]; then
  pass "each _global scenario is a job on each runner"
else
  fail "_global jobs" "$out"
fi
if [ "$(matrix_jq '[.[] | select(.id != "_global") | has("scenario")]
  | length > 0 and all(. == false)')" = true ]; then
  pass "a Feature's jobs name no scenario"
else
  fail "Feature jobs" "$out"
fi

new_pushed_repo README.md
out=$(emit pull_request)
if grep -qx 'matrix=\[\]' <<<"$out" && grep -qx "base=$base" <<<"$out"; then
  pass "a PR changing no Feature runs nothing"
else
  fail "PR, docs change" "$out"
fi

new_repo
echo '{}' >test/_global/scenarios.json
commit
if grep -qx rc=1 <<<"$(emit schedule)"; then
  pass "_global without scenarios fails"
else
  fail "_global without scenarios" "$(emit schedule)"
fi

# grep -q exits at its first match; piped, a long git diff would die of
# SIGPIPE, which pipefail would read as no match.
new_repo
echo '# a change' >>.github/scripts/emit-features.sh
mkdir -p docs/bulk
for i in $(seq 1600); do
  echo "$i" >"docs/bulk/a-file-with-a-long-enough-name-$i.md"
done
commit
runs=0
for _ in $(seq 5); do
  out=$(emit pull_request)
  if grep -qx rc=0 <<<"$out" && grep -qF "$full" <<<"$out"; then
    runs=$((runs + 1))
  fi
done
if [ "$runs" -eq 5 ]; then
  pass "a 1,600-path diff whose first path matches runs everything"
else
  fail "long diff" "$runs/5 runs"
fi

# --- test-features.sh, against stub devcontainer and docker CLIs ---

new_repo
mkdir -p node_modules/.bin stubs test/fixture
cat >node_modules/.bin/devcontainer <<'EOF'
#!/bin/bash
echo "$*" >>"$STUB_LOG"
EOF
echo '#!/bin/bash' >stubs/docker
chmod +x node_modules/.bin/devcontainer stubs/docker
echo '{"one": {}, "two-rebuild": {}}' >test/fixture/scenarios.json
export STUB_LOG=$PWD/stub.log
features_test() { # scenario...
  CI=true PATH=$PWD/stubs:$PATH .github/scripts/test-features.sh fixture "$@"
}
# Checks the exit status, then the scenarios the CLI ran, one line per run.
expect_runs() { # name want scenario...
  local name=$1 want=$2 out
  shift 2
  : >"$STUB_LOG"
  features_test "$@" >/dev/null 2>&1
  out="rc=$?"$'\n'$(sed -n 's/.* --filter \([^ ]*\) .*/\1/p' "$STUB_LOG")
  if [ "$out" = "$want" ]; then
    pass "$name"
  else
    fail "$name" "$out"
  fi
}
all=$'rc=0\none\ntwo-rebuild\ntwo-rebuild'
expect_runs "test-features.sh runs each scenario, a rebuild twice" "$all"
expect_runs "test-features.sh with an empty scenario name runs each" "$all" ""
expect_runs "test-features.sh with a scenario runs only it" $'rc=0\none' one
expect_runs "test-features.sh with a rebuild scenario runs it twice" \
  $'rc=0\ntwo-rebuild\ntwo-rebuild' two-rebuild
expect_runs "test-features.sh with an unknown scenario runs none" \
  $'rc=1\n' nope
expect "test-features.sh names the unknown scenario" 1 \
  "no scenario named nope" features_test nope

# --- lib/fetch_verified.sh, against a stub curl ---

# The stub rejects --retry-all-errors when OLD_CURL is set, as curl before
# 7.71 does, and logs each download's flags.
stubs=$(mktemp -d "$root/curl.XXXX")
cat >"$stubs/curl" <<'EOF'
#!/bin/bash
if [ "$2" = --version ]; then
  [ -z "${OLD_CURL:-}" ]
  exit
fi
echo "$*" >>"$STUB_LOG"
exit 22
EOF
chmod +x "$stubs/curl"
retry_flags() { # old (non-empty for an old curl)
  : >"$STUB_LOG"
  (
    # shellcheck source=../../lib/fetch_verified.sh
    . "$repo/lib/fetch_verified.sh"
    PATH=$stubs:$PATH OLD_CURL=$1 fetch_verified https://x 00 "$root/dest"
  )
  grep -c -- --retry-all-errors "$STUB_LOG"
}
if [ "$(retry_flags '')" = 1 ] && [ "$(retry_flags old)" = 0 ] \
  && grep -q -- '--retry 3' "$STUB_LOG"; then
  pass "fetch_verified retries every error where curl can"
else
  fail "fetch_verified's retries" "$(cat "$STUB_LOG")"
fi

# --- check-pending.sh and check-visibility.sh, against a stub CLI ---

# gh-config is published at its version, claude-code only at an older one,
# liza's lookup fails, and the rest aren't published. grimoire is private.
new_repo
mkdir -p node_modules/.bin
cat >node_modules/.bin/devcontainer <<'EOF'
#!/bin/bash
id=${4%:1}
id=${id##*/}
echo "$3 $id token=${GITHUB_TOKEN:-none} config=${DOCKER_CONFIG:-none}" \
  >>"$STUB_LOG"
case "$3 $id" in
  "tags gh-config") echo '{"publishedTags":["1","1.0","1.0.0","latest"]}' ;;
  "tags claude-code") echo '{"publishedTags":["1","0.9.0"]}' ;;
  "tags grimoire") echo '{"publishedTags":["1","latest"]}' ;;
  "tags liza") exit 1 ;;
  "manifest grimoire") exit 1 ;;
  manifest*) echo '{}' ;;
  *)
    echo '{}'
    exit 1
    ;;
esac
EOF
chmod +x node_modules/.bin/devcontainer
export STUB_LOG=$PWD/stub.log

# shellcheck source=feature_ids.sh
. .github/scripts/feature_ids.sh
want=$(feature_ids | grep -vx gh-config | paste -sd' ' -)
out=$(GITHUB_TOKEN=secret .github/scripts/check-pending.sh 2>/dev/null)
if [ "$out" = "$want" ] && grep -qw claude-code <<<"$out" \
  && grep -qw liza <<<"$out"; then
  pass "check-pending lists every id not published at its version"
else
  fail "check-pending list" "got '$out', want '$want'"
fi
if grep -q "tags gh-config token=secret" "$STUB_LOG"; then
  pass "check-pending queries the registry with the token"
else
  fail "query token" "$(cat "$STUB_LOG")"
fi
cp src/grimoire/CHANGELOG.md changelog.keep
version=$(jq -r .version src/grimoire/devcontainer-feature.json)
printf '## %s\n' "$version" >src/grimoire/CHANGELOG.md
expect "check-pending fails on an invalid changelog" 1 \
  "the '## $version' entry is empty" \
  env GITHUB_TOKEN=secret .github/scripts/check-pending.sh
mv changelog.keep src/grimoire/CHANGELOG.md
mv .github/scripts/check-changelog.sh check-changelog.keep
cat >.github/scripts/check-changelog.sh <<'STUB'
#!/bin/bash
echo "changelog token=${GITHUB_TOKEN:-none}" >>"$STUB_LOG"
STUB
chmod +x .github/scripts/check-changelog.sh
: >"$STUB_LOG"
GITHUB_TOKEN=secret .github/scripts/check-pending.sh >/dev/null 2>&1
if grep -q "changelog token=none" "$STUB_LOG" \
  && ! grep -q "changelog token=secret" "$STUB_LOG"; then
  pass "check-pending checks changelogs without the token"
else
  fail "changelog token" "$(cat "$STUB_LOG")"
fi
mv check-changelog.keep .github/scripts/check-changelog.sh

# Since the base commit, only claude-code's version changes.
set_version claude-code 1.0.2
prepend_changelog claude-code '## 1.0.2\n\n- Fix.\n\n'
echo '# later' >>src/claude-code/install.sh
echo '# unreleased' >>src/gh-config/install.sh
commit
expect "with a commit, check-pending lists only versions changed since" 0 "" \
  test "$(GITHUB_TOKEN=secret .github/scripts/check-pending.sh "$base" \
    2>/dev/null)" = claude-code
expect "and nothing with no version changed since" 0 "" \
  test -z "$(GITHUB_TOKEN=secret .github/scripts/check-pending.sh HEAD \
    2>/dev/null)"
missing=$(feature_ids | grep -vx gh-config | paste -sd' ' -)
expect "--report fails on every version missing from GHCR" 1 \
  "::error::not on GHCR at main's version: $missing." \
  env GITHUB_TOKEN=secret .github/scripts/check-pending.sh --report
since=$(git rev-parse HEAD)
mkdir -p src/new-id
jq '.id = "new-id" | .version = "1.0.0"' \
  src/gh-config/devcontainer-feature.json >src/new-id/devcontainer-feature.json
printf '## 1.0.0\n\n- First release.\n' >src/new-id/CHANGELOG.md
set_version claude-code 0.9.0
commit
expect "a Feature new since the commit counts" 0 "" \
  test "$(GITHUB_TOKEN=secret .github/scripts/check-pending.sh "$since" \
    2>/dev/null)" = new-id
git rm -rq src/new-id
set_version claude-code 1.0.2
commit

# gh-config is published at its base version, claude-code at 0.9.0; both
# versions' tags sit on the base commit.
git tag feature_gh-config_1.0.0 "$base"
git tag feature_claude-code_0.9.0 "$base"
stage() { GITHUB_TOKEN=secret .github/scripts/stage-release.sh stage "$@"; }
stage claude-code >/dev/null 2>&1
expect "stage-release copies a pending Feature from the working tree" 0 \
  "# later" cat stage/src/claude-code/install.sh
expect "and every other published one from its tag" 0 "" \
  test -f stage/src/gh-config/install.sh
expect_not "without its unreleased changes" "# unreleased" \
  cat stage/src/gh-config/install.sh
expect "leaving out one never published" 1 "" test -e stage/src/container-env
expect "and one with no X.Y.Z published" 1 "" test -e stage/src/grimoire
rm -rf stage
git tag -d feature_gh-config_1.0.0 >/dev/null
expect "a published Feature with no tag yet comes from" 0 \
  "no tag feature_gh-config_1.0.0 yet" stage claude-code
expect "the commit that set its version, when that's the published one" 0 \
  "" test -f stage/src/gh-config/install.sh
expect_not "without changes since" "# unreleased" \
  cat stage/src/gh-config/install.sh
rm -rf stage
git tag feature_gh-config_1.0.0 "$base"
git tag -d feature_claude-code_0.9.0 >/dev/null
expect "but fails when it isn't" 1 "no tag feature_claude-code_0.9.0 to stage" \
  stage gh-config
git tag feature_claude-code_0.9.0 "$base"
git tag feature_liza_0.1.0 "$base"
expect "and so does a failed lookup of one published" 1 \
  "::error::liza: the GHCR lookup failed" stage claude-code
git tag -d feature_liza_0.1.0 >/dev/null
expect "stage-release takes only Features" 1 "no Feature nope" stage nope
expect "stage-release wants an id" 2 "usage" \
  .github/scripts/stage-release.sh stage
rm -rf stage

: >"$STUB_LOG"
expect "check-visibility names each private Feature" 1 \
  "::error::not publicly readable at :1: grimoire" \
  env GITHUB_TOKEN=secret .github/scripts/check-visibility.sh
if [ "$(grep -c '^manifest ' "$STUB_LOG")" -eq "$(feature_ids | wc -l)" ] \
  && ! grep -q "token=secret" "$STUB_LOG" \
  && ! grep -q "config=none" "$STUB_LOG"; then
  pass "check-visibility queries each Feature without credentials"
else
  fail "check-visibility credentials" "$(cat "$STUB_LOG")"
fi
sed -i '/"manifest grimoire"/d' node_modules/.bin/devcontainer
expect "check-visibility passes when every Feature is public" 0 "" \
  .github/scripts/check-visibility.sh

# --- tag-release.sh, against stub devcontainer and gh CLIs ---

# A Feature's version is on GHCR when PUBLISHED lists <id>@<version>; liza's
# lookup fails. The gh stub keeps tags as "<name> <commit>" lines in TAGS:
# DENY makes creating that tag a 403, and MEANWHILE has another run create it
# first.
new_repo
mkdir -p node_modules/.bin stubs
cat >node_modules/.bin/devcontainer <<'EOF'
#!/bin/bash
id=${4%:1}
id=${id##*/}
[ "$id" != liza ] || exit 1
for p in $PUBLISHED; do
  [ "${p%@*}" != "$id" ] || echo "${p#*@}"
done | jq -R . | jq -s '{publishedTags: (["1"] + .)}'
EOF
cat >stubs/gh <<'EOF'
#!/bin/bash
shift
path='' filter='' ref='' sha=''
while [ "$#" -gt 0 ]; do
  case $1 in
    --paginate) ;;
    --jq) filter=$2 && shift ;;
    -f)
      case $2 in
        ref=*) ref=${2#ref=} ;;
        sha=*) sha=${2#sha=} ;;
      esac
      shift
      ;;
    *) path=$1 ;;
  esac
  shift
done
out() { if [ -n "$filter" ]; then jq -r "$filter"; else cat; fi; }
git=repos/example/repo/git
case $path in
  "$git/refs")
    tag=${ref#refs/tags/}
    if [ "$tag" = "${DENY:-}" ]; then
      echo 'gh: Resource not accessible by integration (HTTP 403)' >&2
      exit 1
    fi
    [ "$tag" != "${MEANWHILE:-}" ] || echo "$tag $sha" >>"$TAGS"
    if grep -q "^$tag " "$TAGS"; then
      echo 'gh: Reference already exists (HTTP 422)' >&2
      exit 1
    fi
    echo "$tag $sha" >>"$TAGS"
    ;;
  "$git/ref/tags/"*)
    line=$(grep "^${path#"$git/ref/tags/"} " "$TAGS") \
      || { echo 'gh: Not Found (HTTP 404)' >&2 && exit 1; }
    jq -n --arg s "${line#* }" '{object: {sha: $s}}' | out
    ;;
  "$git/matching-refs/tags/feature_")
    jq -R '{ref: ("refs/tags/" + (split(" ")[0]))}' "$TAGS" | jq -s . | out
    ;;
  *) echo "stub gh: unexpected path $path" >&2 && exit 1 ;;
esac
EOF
chmod +x node_modules/.bin/devcontainer stubs/gh
export TAGS=$PWD/tags PUBLISHED='gh-config@2.0.0 grimoire@2.0.0'
: >"$TAGS"
tag() {
  PATH=$PWD/stubs:$PATH GH_TOKEN=t GITHUB_REPOSITORY=example/repo \
    .github/scripts/tag-release.sh "$@"
}
set_version gh-config 2.0.0
set_version grimoire 2.0.0
commit
c1=$(git rev-parse HEAD)
echo docs >>src/gh-config/README.md
commit
c2=$(git rev-parse HEAD)
set_version gh-config 2.1.0
commit

expect "tag-release tags a published version at the commit" 0 \
  "tagged feature_gh-config_2.0.0" tag "$c1" gh-config
expect "on that commit" 0 "" grep -qxF "feature_gh-config_2.0.0 $c1" "$TAGS"
expect "reading the version there, not in the working tree" 0 \
  "feature_gh-config_2.1.0: not on GHCR" tag HEAD gh-config
expect "a version not on GHCR isn't tagged" 0 "" test "$(wc -l <"$TAGS")" = 1
expect "a tag already on the commit passes" 0 \
  "feature_gh-config_2.0.0: already on this commit" tag "$c1" gh-config
expect "a tag never moves" 1 "already points at $c1, not $c2" \
  tag "$c2" gh-config
out=$(DENY=feature_grimoire_2.0.0 tag "$c1" grimoire liza gh-config 2>&1)
rc=$?
expect "a refused tag fails the run" 0 "" test "$rc" = 1
expect "naming the likely cause" 0 "likely cause: main's workflows changed" \
  echo "$out"
expect "a failed lookup fails too" 0 "the GHCR lookup failed" echo "$out"
expect "after every id had its turn" 0 \
  "feature_gh-config_2.0.0: already on this commit" echo "$out"
out=$(MEANWHILE=feature_grimoire_2.0.0 tag "$c1" grimoire 2>&1)
rc=$?
expect "a tag made meanwhile on the commit passes" 0 \
  "feature_grimoire_2.0.0: already on this commit" \
  sh -c "[ $rc = 0 ] && echo \"\$1\"" _ "$out"
expect "an id with no Feature at the commit fails" 1 "no src/nope/" \
  tag "$c1" nope

expect_not "--untagged is quiet when every published version has a tag" \
  "::warning::" tag --untagged
PUBLISHED="$PUBLISHED gh-config@2.1.0"
expect "--untagged warns of a published version with no tag" 0 \
  "::warning::feature_gh-config_2.1.0 is on GHCR but has no tag" \
  tag --untagged
expect_not "but not of a failed lookup" "feature_liza_" tag --untagged

summary
