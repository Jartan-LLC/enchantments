#!/bin/bash
# shellcheck source-path=SCRIPTDIR
# shellcheck disable=SC2016 # backticks are Markdown
# Tests pin-bumps.sh's helpers and lookups offline: the lookups run against
# stub gh, curl and uv commands that serve fixtures. Every real pins.sh is
# also checked against the format the lookups parse. Prints one line per case
# and exits non-zero if any fails.
set -uo pipefail
scripts=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$scripts/../.." && pwd)
# shellcheck source=pins_lib.sh
. "$scripts/pins_lib.sh"
# shellcheck source=pin_lookups.sh
. "$scripts/pin_lookups.sh"
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
passed=0
failed=0

pass() { # name
  echo "ok   $1"
  passed=$((passed + 1))
}
fail() { # name detail
  echo "FAIL $1: $2"
  failed=$((failed + 1))
}
# Checks that a command succeeds (or fails, for status 1) and prints want.
expect() { # name status want command...
  local name=$1 status=$2 want=$3 out rc
  shift 3
  out=$("$@" 2>&1)
  rc=$?
  if { [ "$status" = 0 ] && [ "$rc" = 0 ]; } \
    || { [ "$status" = 1 ] && [ "$rc" != 0 ]; }; then
    if [ -z "$want" ] || grep -qF -- "$want" <<<"$out"; then
      pass "$name"
      return
    fi
  fi
  fail "$name" "exit $rc, want $status '$want': $out"
}
# Checks that a command's output has no line containing unwanted.
expect_not() { # name unwanted command...
  local name=$1 unwanted=$2 out
  shift 2
  out=$("$@" 2>&1)
  if grep -qF -- "$unwanted" <<<"$out"; then
    fail "$name" "printed '$unwanted': $out"
  else
    pass "$name"
  fi
}

# --- Every real pins.sh -------------------------------------------------------

# Succeeds when each pin has the values its lookup reads, each well formed.
pins_well_formed() { # file
  local file=$1 kind tool prefix name value
  while read -r kind tool; do
    case $kind in
      asset)
        pin_attr "$file" "$tool" repo >/dev/null || return 1
        prefix=$(pin_prefix "$file" "$tool" _TAG)
        valid version "$(pin_get "$file" "${prefix}_TAG")" || return 1
        [ -n "$(pin_arches "$file" "$tool" "${prefix}_ASSET")" ] || return 1
        ;;
      tag-commit)
        prefix=$(pin_prefix "$file" "$tool" _TAG)
        valid commit "$(pin_get "$file" "${prefix}_COMMIT")" || return 1
        ;;
      branch-commit)
        prefix=$(pin_prefix "$file" "$tool" _COMMIT)
        valid commit "$(pin_get "$file" "${prefix}_COMMIT")" || return 1
        ;;
      hf-model)
        pin_attr "$file" "$tool" model >/dev/null || return 1
        prefix=$(pin_prefix "$file" "$tool" _REVISION)
        valid commit "$(pin_get "$file" "${prefix}_REVISION")" || return 1
        ;;
      node | go)
        prefix=$(pin_prefix "$file" "$tool" _VERSION)
        valid version "$(pin_get "$file" "${prefix}_VERSION")" || return 1
        ;;
      uv-lock)
        [ -f "$(dirname "$file")/$(pin_attr "$file" "$tool" lock)" ] \
          && [ -f "$(dirname "$file")/$(pin_attr "$file" "$tool" input)" ] \
          || return 1
        continue
        ;;
      *) return 1 ;;
    esac
    [ -n "$prefix" ] || return 1
    # Every digest under the pin is a sha256.
    while IFS='=' read -r name value; do
      case $name in *_SHA256_*) valid sha256 "$value" || return 1 ;; esac
    done < <(pin_vars "$file" "$tool")
  done < <(pin_list "$file")
}

for file in "$repo"/src/*/pins.sh; do
  id=$(basename "$(dirname "$file")")
  expect "$id's pins.sh has a pin" 0 "" test -n "$(pin_list "$file")"
  expect "$id's pins are well formed" 0 "" pins_well_formed "$file"
done

# --- Helpers ------------------------------------------------------------------

pins=$root/pins.sh
ones=$(printf '1%.0s' {1..64})
twos=$(printf '2%.0s' {1..64})
cat >"$pins" <<EOF
# pin asset demo repo=example/demo
DEMO_TAG='v1.2.0'
DEMO_ASSET_X86_64='demo-{version}-x86_64.tar.gz'
DEMO_SHA256_X86_64='$ones'
DEMO_ASSET_AARCH64='demo-{tag}-aarch64.tar.gz'
DEMO_SHA256_AARCH64='$twos'

# pin branch-commit tool repo=example/tool
TOOL_COMMIT='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
EOF
expect "pin_list lists each header" 0 "branch-commit tool" pin_list "$pins"
expect "pin_attr reads repo=" 0 example/tool pin_attr "$pins" tool repo
expect "pin_attr fails on a missing key" 1 "" pin_attr "$pins" tool model
expect "pin_vars stops at the blank line" 0 "" \
  test "$(pin_vars "$pins" demo | wc -l)" = 5
expect "pin_arches lists X86_64" 0 X86_64 pin_arches "$pins" demo DEMO_ASSET

cp "$pins" "$root/set.sh"
pin_set "$root/set.sh" DEMO_TAG v1.3.0
expect "pin_set writes the value" 0 v1.3.0 pin_get "$root/set.sh" DEMO_TAG
expect "pin_set changes only that line" 0 "" \
  test "$(diff "$pins" "$root/set.sh" | grep -c '^[<>]')" = 2
expect "pin_set refuses a quote" 1 "" pin_set "$root/set.sh" DEMO_TAG "a'b"
expect "pin_set refuses an unknown name" 1 "" pin_set "$root/set.sh" NOPE x

expect "valid takes a tag" 0 "" valid version v1.2.3-rc.1+build
expect "valid refuses a path" 1 "" valid version ../x
expect "valid refuses a space" 1 "" valid name "a b"
expect "valid takes a commit" 0 "" valid commit "$(printf 'a%.0s' {1..40})"
expect "valid refuses a short commit" 1 "" valid commit abc123
expect "valid refuses an uppercase sha256" 1 "" \
  valid sha256 "$(printf 'A%.0s' {1..64})"

expect "version_gt orders numerically" 0 "" version_gt 0.45.10 0.45.3
expect "version_gt ignores a leading v" 0 "" version_gt v1.10.0 1.9.9
expect "version_gt is false for equal" 1 "" version_gt v1.2.0 1.2.0
expect "version_gt is false for older" 1 "" version_gt 1.2.0 1.10.0

expect "expand_asset fills {version}" 0 demo-1.3.0-x86_64.tar.gz \
  expand_asset 'demo-{version}-x86_64.tar.gz' v1.3.0
expect "expand_asset fills {tag}" 0 demo-v1.3.0-aarch64.tar.gz \
  expand_asset 'demo-{tag}-aarch64.tar.gz' v1.3.0
expect "bump_minor raises the minor" 0 1.10.0 bump_minor 1.9.3

# A changelog edit passes the version check's own changelog rule.
changelog_case() { # name changelog
  local dir
  dir=$(mktemp -d "$root/log.XXXX")
  last_log=$dir/src/demo/CHANGELOG.md
  mkdir -p "$dir/src/demo"
  echo '{"id": "demo", "version": "1.1.0"}' \
    >"$dir/src/demo/devcontainer-feature.json"
  printf '%b' "$2" >"$dir/src/demo/CHANGELOG.md"
  echo '- `uv`: 0.1.0 → 0.2.0' >"$dir/entry"
  add_changelog_entry "$dir/src/demo/CHANGELOG.md" 1.1.0 "$dir/entry"
  expect "$1 passes check-changelog --bump" 0 "" \
    bash -c "cd '$dir' && '$scripts/check-changelog.sh' --bump demo"
  expect "$1 keeps the older entry" 0 "## 1.0.0" \
    cat "$dir/src/demo/CHANGELOG.md"
}
changelog_case "a changelog entry" '## 1.0.0\n\n- First release.\n'
changelog_case "an entry over Unreleased" \
  '## Unreleased\n\n- A docs fix.\n\n## 1.0.0\n\n- First release.\n'
expect "the Unreleased line moves into the entry" 0 "- A docs fix." \
  awk '/^## 1.1.0/,/^## 1.0.0/' "$last_log"

body=$'Text\n\nExcluded: `uv@0.2.0`, `bad key`, `go@1.27.2`\n'
body+='<!-- pin-bumps held: uv@0.3.0 rtk@v1 -->'
expect "body_excluded reads the keys" 0 go@1.27.2 body_excluded "$body"
expect_not "body_excluded drops a bad key" "bad key" body_excluded "$body"
expect "body_excluded reads none as empty" 0 "" \
  test -z "$(body_excluded 'Excluded: none')"
expect "body_held reads the hidden line" 0 rtk@v1 body_held "$body"

# --- Lookups, against stubs ---------------------------------------------------

# Fixtures live under $fixtures, named by the request with every character
# that isn't alphanumeric turned into _. The stubs serve them; a missing one
# is a failed request.
fixtures=$root/fixtures
mkdir -p "$fixtures" "$root/bin"
fixture() { # request
  echo "$fixtures/$(tr -c 'A-Za-z0-9\n' _ <<<"$1")"
}
serve() { # request (content on stdin)
  cat >"$(fixture "$1")"
}
cat >"$root/bin/gh" <<'EOF'
#!/bin/bash
# Stub gh: "api [--paginate] <path> [--jq <filter>]", from fixtures.
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
file=$FIXTURES/$(tr -c 'A-Za-z0-9\n' _ <<<"$path")
[ -f "$file" ] || { echo "stub gh: no fixture for $path" >&2 && exit 1; }
if [ -n "$filter" ]; then jq -r "$filter" "$file"; else cat "$file"; fi
EOF
cat >"$root/bin/curl" <<'EOF'
#!/bin/bash
# Stub curl: prints a URL's fixture, its headers with -I, or writes it with -o.
out='' url='' head=''
while [ "$#" -gt 0 ]; do
  case $1 in
    -o) out=$2 && shift ;;
    -fsSI) head=1 ;;
    -*) ;;
    *) url=$1 ;;
  esac
  shift
done
file=$FIXTURES/$(tr -c 'A-Za-z0-9\n' _ <<<"${head:+HEAD }$url")
[ -f "$file" ] || exit 22
if [ -n "$out" ]; then cp "$file" "$out"; else cat "$file"; fi
EOF
cat >"$root/bin/uv" <<'EOF'
#!/bin/bash
# Stub uv: "pip compile ... -o <out>" writes the fixture lock.
while [ "$#" -gt 0 ]; do
  [ "$1" = -o ] && cp "$FIXTURES/lock" "$2"
  shift
done
EOF
chmod +x "$root/bin/"*
export PATH=$root/bin:$PATH FIXTURES=$fixtures
CUTOFF=$(date -u -d 2026-09-01T00:00:00Z +%s)
export CUTOFF
old=2026-08-01T00:00:00Z
new=2026-09-20T00:00:00Z

sha_a=$(printf 'x86 bytes' | sha256sum | cut -d' ' -f1)
sha_b=$(printf 'arm bytes' | sha256sum | cut -d' ' -f1)
release() { # tag assets-updated digest-a
  cat <<EOF
{"tag_name": "$1", "assets": [
  {"name": "demo-${1#v}-x86_64.tar.gz", "updated_at": "$2",
   "digest": "sha256:$3", "browser_download_url": "https://dl/$1/a"},
  {"name": "demo-$1-aarch64.tar.gz", "updated_at": "$2",
   "digest": "sha256:$sha_b", "browser_download_url": "https://dl/$1/b"}]}
EOF
}
# Prints a release-list entry.
listed() { # tag draft prerelease published
  printf '{"tag_name": "%s", "draft": %s, "prerelease": %s,' "$1" "$2" "$3"
  printf ' "published_at": "%s"}' "$4"
}
{
  echo "[$(listed v9.0.0 true false "$old"),"
  echo "$(listed v8.0.0 false true "$old"),"
  echo "$(listed v2.1.0 false false "$new"),"
  echo "$(listed v2.0.0 false false "$old"),"
  echo "$(listed v1.3.0 false false "$old")]"
} | serve 'repos/example/demo/releases?per_page=100'
release v2.0.0 "$new" "$sha_a" | serve repos/example/demo/releases/tags/v2.0.0
release v1.3.0 "$old" "$sha_a" | serve repos/example/demo/releases/tags/v1.3.0
printf 'x86 bytes' | serve https://dl/v1.3.0/a
printf 'arm bytes' | serve https://dl/v1.3.0/b

asset() { lookup_asset "$pins" demo; }
expect "an asset lookup skips drafts, prereleases and recent releases" 0 \
  "candidate v1.3.0" asset
expect "an asset whose file changed recently holds its release back" 0 \
  "release v1.3.0 demo-1.3.0-x86_64.tar.gz" asset
expect "an asset lookup hashes the download" 0 \
  "set DEMO_SHA256_AARCH64 $sha_b" asset
expect "an asset lookup writes the tag" 0 "set DEMO_TAG v1.3.0" asset
expect "an asset lookup names the exclusion key" 0 "key demo@v1.3.0" asset
dry_asset() { DRY_RUN=1 lookup_asset "$pins" demo; }
expect "a dry run takes GitHub's digest" 0 "set DEMO_SHA256_X86_64 $sha_a" \
  dry_asset

printf 'tampered' | serve https://dl/v1.3.0/a
expect "a download that doesn't match GitHub's digest fails" 1 \
  "doesn't match GitHub's digest" asset
printf 'x86 bytes' | serve https://dl/v1.3.0/a

cp "$pins" "$root/current.sh"
pin_set "$root/current.sh" DEMO_TAG v1.3.0
expect_not "a pin already at the newest aged release has no candidate" \
  candidate lookup_asset "$root/current.sh" demo

release v1.3.0 "$old" "$sha_a" | jq '.assets |= .[:1]' \
  | serve repos/example/demo/releases/tags/v1.3.0
expect "a release missing a pinned asset name fails" 1 \
  "has no asset demo-v1.3.0-aarch64.tar.gz" asset
release v1.3.0 "$old" "$sha_a" | serve repos/example/demo/releases/tags/v1.3.0

# branch-commit: the newest aged push still on the branch wins.
c1=$(printf '1%.0s' {1..40}) c2=$(printf '2%.0s' {1..40})
c3=$(printf '3%.0s' {1..40}) cur=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
echo '{"default_branch": "main"}' | serve repos/example/tool
serve 'repos/example/tool/activity?ref=main&per_page=100' <<EOF
[{"activity_type": "push", "timestamp": "$new", "after": "$c1"},
 {"activity_type": "force_push", "timestamp": "$old", "after": "$c2"},
 {"activity_type": "branch_creation", "timestamp": "$old", "after": "$c3"},
 {"activity_type": "pr_merge", "timestamp": "$old", "after": "$c3"}]
EOF
echo '{"status": "diverged"}' | serve "repos/example/tool/compare/$c2...main"
echo '{"status": "ahead"}' | serve "repos/example/tool/compare/$c3...main"
echo '{"status": "ahead"}' | serve "repos/example/tool/compare/$cur...$c3"
expect "a branch commit skips recent and force-pushed-away pushes" 0 \
  "set TOOL_COMMIT $c3" lookup_branch_commit "$pins" tool
echo '{"status": "behind"}' | serve "repos/example/tool/compare/$cur...$c3"
expect_not "a branch commit behind the pin isn't proposed" candidate \
  lookup_branch_commit "$pins" tool
echo '{"status": "diverged"}' | serve "repos/example/tool/compare/$c3...main"
expect "no aged commit still on the branch fails" 1 "pushed 7 or more days" \
  lookup_branch_commit "$pins" tool

# uv-lock: kept only when something moved up and nothing moved down.
lockdir=$root/src/demo
mkdir -p "$lockdir"
{
  echo '# pin uv-lock semble lock=lock.txt input=semble.in'
  echo "SEMBLE_REQUIREMENTS='lock.txt'"
} >"$lockdir/pins.sh"
echo semble >"$lockdir/semble.in"
printf '# header\nsemble==1.0.0 \\\nanyio==4.1.0 \\\n' >"$lockdir/lock.txt"
uv_lock() { (cd "$root" && lookup_uv_lock src/demo/pins.sh semble); }
printf 'semble==1.1.0 \\\nanyio==4.1.0 \\\n' >"$fixtures/lock"
expect "a lock with a requirement moved up is offered" 0 \
  "change semble: 1.0.0 → 1.1.0" uv_lock
printf 'semble==1.1.0 \\\nAnyIO==4.0.0 \\\n' >"$fixtures/lock"
expect_not "a lock with a requirement moved down isn't" candidate uv_lock
printf 'semble==1.0.0 \\\nanyio==4.1.0 \\\n' >"$fixtures/lock"
expect_not "an unchanged lock isn't" candidate uv_lock

# --- End to end, against a local remote and a stub GitHub ---------------------

# The remote is a bare repo. The stub gh keeps pull requests in $PRS, reads a
# PR's commit authors from the remote's branch as GitHub would, and serves
# everything else from fixtures.
origin=$root/origin.git
export ORIGIN=$origin PRS=$root/prs.json
mkdir -p "$root/e2e-bin"
cat >"$root/e2e-bin/gh" <<'STUB'
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
  "GET $pulls?"*) out <"$PRS" ;;
  "POST $pulls")
    n=$(($(jq length "$PRS") + 1))
    jq --argjson n "$n" --slurpfile r "$input" '. + [$r[0] + {number: $n,
      state: "open", merged_at: null,
      created_at: "2026-10-0\($n)T00:00:00Z"}]' \
      "$PRS" >"$PRS.tmp" && mv "$PRS.tmp" "$PRS"
    echo "{\"number\": $n}" | out
    ;;
  "GET $pulls/"*/commits*)
    git -C "$ORIGIN" log --format=%ae main..pin-bumps/demo \
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
  *)
    file=$FIXTURES/$(tr -c 'A-Za-z0-9\n' _ <<<"$path")
    [ -f "$file" ] || { echo "stub gh: no fixture for $path" >&2 && exit 1; }
    out <"$file"
    ;;
esac
STUB
chmod +x "$root/e2e-bin/gh"
echo '[]' >"$PRS"

seed=$root/seed
git init -q -b main "$seed"
mkdir -p "$seed/src/demo"
echo '{"id": "demo", "version": "1.0.0"}' \
  >"$seed/src/demo/devcontainer-feature.json"
printf '## 1.0.0\n\n- First release.\n' >"$seed/src/demo/CHANGELOG.md"
{
  echo '# pin branch-commit tool repo=example/tool'
  echo "TOOL_COMMIT='$cur'"
} >"$seed/src/demo/pins.sh"
git -C "$seed" add -A
git -C "$seed" -c user.name=t -c user.email=t@t commit -qm seed
git clone -q --bare "$seed" "$origin"
run=$root/run
git clone -q "$origin" "$run"

# Lookup fixtures dated from now, since the script sets its own cutoff.
aged_at=$(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%SZ)
pushed() { # commit...
  local commit sep=''
  echo '['
  for commit in "$@"; do
    printf '%s{"activity_type": "push", "timestamp": "%s", "after": "%s"}\n' \
      "$sep" "$aged_at" "$commit"
    sep=,
  done
  echo ']'
}
pushed "$c3" | serve 'repos/example/tool/activity?ref=main&per_page=100'
echo '{"status": "ahead"}' | serve "repos/example/tool/compare/$c3...main"
echo '{"status": "ahead"}' | serve "repos/example/tool/compare/$cur...$c3"

bump() {
  (cd "$run" && PATH=$root/e2e-bin:$PATH GH_TOKEN=token APP_SLUG=pinbot \
    GITHUB_REPOSITORY=example/repo "$scripts/pin-bumps.sh" \
    --report "$root/report")
}
remote_file() { git -C "$origin" show "pin-bumps/demo:src/demo/$1"; }
pr() { jq -r ".[$1 - 1].$2" "$PRS"; }
branch_is() { # rev
  test "$(git -C "$origin" rev-parse pin-bumps/demo)" \
    = "$(git -C "$origin" rev-parse "$1")"
}
on_main() {
  test "$(git -C "$origin" rev-parse pin-bumps/demo^)" \
    = "$(git -C "$origin" rev-parse main)"
}

expect "a newer pin opens a PR" 0 "demo: opened #1" bump
expect "the branch holds the new pin" 0 "TOOL_COMMIT='$c3'" remote_file pins.sh
expect "the branch raises the minor version" 0 '"version": "1.1.0"' \
  remote_file devcontainer-feature.json
expect "the changelog entry lists the bump" 0 "## 1.1.0" \
  remote_file CHANGELOG.md
expect "the commit is the App's" 0 \
  "42+pinbot[bot]@users.noreply.github.com" \
  git -C "$origin" log -1 --format=%ae pin-bumps/demo
expect "the PR holds the version" 0 "held: tool@$c3" pr 1 body
expect "the report has the lookup" 0 "$(printf 'lookup\ttool\tok')" \
  cat "$root/report"

head=$(git -C "$origin" rev-parse pin-bumps/demo)
expect "an unchanged rerun pushes nothing" 0 "pin-bumps/demo unchanged" bump
expect "and keeps the branch" 0 "" branch_is "$head"
expect "and opens no second PR" 0 "" test "$(jq length "$PRS")" = 1

# A hand edit stops the rebuilds.
hand=$root/hand
git clone -q -b pin-bumps/demo "$origin" "$hand"
echo note >"$hand/src/demo/NOTES.md"
git -C "$hand" add -A
git -C "$hand" -c user.name=me -c user.email=me@example.com commit -qm hand
git -C "$hand" push -q origin pin-bumps/demo
hand_head=$(git -C "$origin" rev-parse pin-bumps/demo)
c4=$(printf '4%.0s' {1..40})
pushed "$c4" "$c3" | serve 'repos/example/tool/activity?ref=main&per_page=100'
echo '{"status": "ahead"}' | serve "repos/example/tool/compare/$c4...main"
echo '{"status": "ahead"}' | serve "repos/example/tool/compare/$cur...$c4"
expect "a hand-edited branch isn't rebuilt" 0 "" bump
expect "and keeps its head" 0 "" branch_is "$hand_head"
expect "and the PR lists what's newer" 0 "Not applied: \`tool@$c4\`" \
  pr 1 body

# Closing the PR unmerged excludes its version.
jq '.[0].state = "closed"' "$PRS" >"$PRS.tmp" && mv "$PRS.tmp" "$PRS"
pushed "$c3" | serve 'repos/example/tool/activity?ref=main&per_page=100'
expect_not "a version from a PR closed unmerged isn't proposed again" \
  opened bump
pushed "$c4" "$c3" | serve 'repos/example/tool/activity?ref=main&per_page=100'
expect "a newer version is" 0 "demo: opened #2" bump
expect "rebuilt from main, past the hand edit" 0 "" on_main
expect "with the closed PR's version excluded" 0 "Excluded: \`tool@$c3\`" \
  pr 2 body

# The Feature moving on main moves the branch onto it.
git -C "$seed" pull -q "$origin" main
echo docs >"$seed/src/demo/README.md"
git -C "$seed" add -A
git -C "$seed" -c user.name=t -c user.email=t@t commit -qm docs
git -C "$seed" push -q "$origin" HEAD:main
expect "a Feature that moved on main moves its branch" 0 \
  "pushed pin-bumps/demo" bump
expect "onto main" 0 "" on_main

# Nothing newer closes the open PR.
echo '{"status": "behind"}' | serve "repos/example/tool/compare/$cur...$c4"
expect "nothing newer closes the PR" 0 "closed #2" bump
expect "which is closed" 0 closed pr 2 state

# --- Tracking issues ---------------------------------------------------------

# The stub gh keeps open issues in $ISSUES and logs each write to $CALLS.
export ISSUES=$root/issues.json CALLS=$root/calls
mkdir -p "$root/issue-bin"
cat >"$root/issue-bin/gh" <<'STUB'
#!/bin/bash
case "$1 $2" in
  "label create") ;;
  "issue list") cat "$ISSUES" ;;
  "issue create")
    title=$(sed -n 's/.*--title \(.*\) --label.*/\1/p' <<<"$*")
    n=$(($(cat "$ISSUES.last" 2>/dev/null || echo 0) + 1))
    echo "$n" >"$ISSUES.last"
    jq --argjson n "$n" --arg t "$title" '. + [{number: $n, title: $t}]' \
      "$ISSUES" >"$ISSUES.tmp" && mv "$ISSUES.tmp" "$ISSUES"
    echo "create $title" >>"$CALLS"
    ;;
  "issue edit") echo "edit $3" >>"$CALLS" ;;
  "issue close")
    jq --argjson n "$3" 'map(select(.number != $n))' "$ISSUES" \
      >"$ISSUES.tmp" && mv "$ISSUES.tmp" "$ISSUES"
    echo "close $3" >>"$CALLS"
    ;;
esac
STUB
chmod +x "$root/issue-bin/gh"
echo '[]' >"$ISSUES"
issues() { # report lines...
  printf '%s\n' "$@" >"$root/issue-report"
  : >"$CALLS"
  PATH=$root/issue-bin:$PATH GITHUB_REPOSITORY=example/repo RUN_URL=run \
    "$scripts/pin-bumps-issues.sh" "$root/issue-report" && cat "$CALLS"
}
tab=$'\t'
expect "a failed lookup opens an issue" 0 \
  "create pin-bumps: uv lookup failing" \
  issues "lookup${tab}uv${tab}fail${tab}can't list releases"
expect "a second failure updates it" 0 "edit 1" \
  issues "lookup${tab}uv${tab}fail${tab}can't list releases"
expect_not "rather than opening another" create \
  issues "lookup${tab}uv${tab}fail${tab}can't list releases"
expect "a clean lookup closes it" 0 "close 1" issues "lookup${tab}uv${tab}ok"
expect "a refused push opens an issue" 0 "create pin-bumps: liza push refused" \
  issues "push${tab}liza${tab}refused"
expect_not "a clean lookup of another tool leaves it open" close \
  issues "lookup${tab}go${tab}ok"
expect "a clean push closes it" 0 "close 2" issues "push${tab}liza${tab}ok"

echo
echo "$passed passed, $failed failed"
[ "$failed" = 0 ]
