#!/bin/bash
# shellcheck source-path=SCRIPTDIR
# Tests the release scripts in .github/scripts against throwaway git repos
# built from this checkout's src/, with a stub devcontainer CLI for the
# registry. Prints one line per case and exits non-zero if any fails.
set -uo pipefail
repo=$(cd "$(dirname "$0")/../.." && pwd)
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
# shellcheck source=test_lib.sh
. "$repo/.github/scripts/test_lib.sh"

# A repo whose base commit copies src/ and the scripts; the change commit
# follows. Leaves the shell in it, with $base set.
new_repo() {
  cd "$(mktemp -d "$root/repo.XXXX")" || exit 1
  git init -q
  git config user.email test@example.com
  git config user.name test
  cp -R "$repo/src" "$repo/test" .
  mkdir -p .github lib && cp -R "$repo/.github/scripts" .github/
  echo x >lib/keep
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
expect "a change without a bump fails" 1 "rise above 1.0.0, but it's 1.0.0" \
  versions

new_repo
echo '# edit' >>src/gh-config/install.sh
set_version gh-config 0.9.0
commit
expect "a lower version fails" 1 "above 1.0.0, but it's 0.9.0" versions

new_repo
set_version gh-config 1.0.0.1
prepend_changelog gh-config '## 1.0.0.1\n\n- Fix.\n\n'
commit
expect "a version that isn't X.Y.Z fails" 1 "must be X.Y.Z" versions

new_repo
set_version gh-config 1.0.1
commit
expect "a bump without an entry fails" 1 "no '## 1.0.1' entry" versions

new_repo
set_version gh-config 1.0.1
prepend_changelog gh-config '## Unreleased\n\n- Doc.\n\n## 1.0.1\n\n- Fix.\n\n'
commit
expect "a line left under Unreleased fails" 1 \
  "'## Unreleased' still has entries" versions

new_repo
set_version gh-config 1.0.1
prepend_changelog gh-config '## Unreleased\n\n## 1.0.1\n\n- Fix.\n\n'
commit
expect "a bump with its entry passes" 0 "" versions

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
set_version grimoire 1.1.0
prepend_changelog grimoire '## 1.1.0\n\n- Moved.\n\n'
commit
expect "a file moved into a bumped Feature fails the one it left" 1 \
  "src/gh-config changed" versions
if ! versions 2>&1 | grep -q grimoire; then
  pass "and passes the one it joined"
else
  fail "and passes the one it joined" "$(versions 2>&1)"
fi

new_repo
set_version gh-config 1.0.1
prepend_changelog gh-config '## 1.0.10\n\n- Other.\n\n'
commit
expect "## 1.0.10 doesn't count as ## 1.0.1" 1 "no '## 1.0.1' entry" versions

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
expect_runs "test-features.sh with an empty scenario runs each" "$all" ""
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
printf '## 1.0.0\n' >src/grimoire/CHANGELOG.md
expect "check-pending fails on an invalid changelog" 1 \
  "the '## 1.0.0' entry is empty" \
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

summary
