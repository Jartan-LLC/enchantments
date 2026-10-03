#!/bin/bash
# shellcheck source-path=SCRIPTDIR
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
# shellcheck source=test_lib.sh
. "$scripts/test_lib.sh"
export COOLDOWN_DAYS=7

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
  # shellcheck disable=SC2016 # Markdown backticks
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

expect "numeric_version takes a v-tag" 0 "" numeric_version v1.2.3
expect "numeric_version refuses an rc" 1 "" numeric_version 1.2.3-rc1
expect "numeric_version refuses a label" 1 "" numeric_version nightly
crlf=$'Intro\r\nExcluded: `a@v1`, `b@v2`\r\n<!-- pin-bumps held: c@v3 -->\r\n'
expect "body_excluded reads a CRLF body's last key" 0 b@v2 \
  body_excluded "$crlf"
expect "body_held reads a CRLF body" 0 c@v3 body_held "$crlf"
marked=$'Intro\nExcluded: none\n<!-- pin-bumps held: a@v1 -->\n'
# shellcheck disable=SC2016 # Markdown backticks
marked+='Not applied: `b@v2`, since this branch has commits from someone else.'
expect_not "body_without_markers drops the held line" "held:" \
  body_without_markers "$marked"
expect_not "and the Not applied line" "Not applied" \
  body_without_markers "$marked"
expect "and keeps Excluded:" 0 "Excluded: none" body_without_markers "$marked"
printf '{\n  "id": "demo",\n  "version": "1.0.0"\n}\n' >"$root/feature.json"
set_version "$root/feature.json" 1.1.0
expect "set_version writes the version" 0 '"version": "1.1.0"' \
  cat "$root/feature.json"

# --- Lookups, against stubs ---------------------------------------------------

# Fixtures live under $fixtures, named by the request with every character
# that isn't alphanumeric turned into _. A fixture whose first line is
# "HTTP <code>" is that error; a missing one is a failed request.
fixtures=$root/fixtures
mkdir -p "$fixtures" "$root/bin"
fixture() { # request
  echo "$fixtures/$(tr -c 'A-Za-z0-9\n' _ <<<"$1")"
}
serve() { # request (content on stdin)
  cat >"$(fixture "$1")"
}
cat >"$root/bin/gh" <<'STUB'
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
[ -z "${STUB_EATS_STDIN:-}" ] || cat >/dev/null
file=$FIXTURES/$(tr -c 'A-Za-z0-9\n' _ <<<"$path")
[ -f "$file" ] || { echo "stub gh: no fixture for $path" >&2 && exit 1; }
read -r first code _ <"$file"
[ "$first" != HTTP ] || { echo "gh: error (HTTP $code)" >&2 && exit 1; }
if [ -n "$filter" ]; then jq -r "$filter" "$file"; else cat "$file"; fi
STUB
cat >"$root/bin/curl" <<'STUB'
#!/bin/bash
# Stub curl: prints a URL's fixture, its headers with -I, or writes it with -o.
echo "$*" >>"$FIXTURES/curl-args"
out='' url='' head=''
while [ "$#" -gt 0 ]; do
  case $1 in
    -o) out=$2 && shift ;;
    -I) head=1 ;;
    *://*) url=$1 ;;
  esac
  shift
done
file=$FIXTURES/$(tr -c 'A-Za-z0-9\n' _ <<<"${head:+HEAD }$url")
[ -f "$file" ] || exit 22
if [ -n "$out" ]; then cp "$file" "$out"; else cat "$file"; fi
STUB
cat >"$root/bin/uv" <<'STUB'
#!/bin/bash
# Stub uv: "pip compile" writes the fixture lock, but only when called with
# the flags that keep the lock hashed, built from wheels and inside the
# cooldown.
args=" $* "
for flag in --universal --generate-hashes --no-build --no-header --upgrade; do
  [[ $args == *" $flag "* ]] || { echo "stub uv: no $flag" >&2 && exit 3; }
done
[ ! -f "$FIXTURES/uv-fails" ] || exit 1
while [ "$#" -gt 0 ]; do
  case $1 in
    --exclude-newer) echo "$2" >"$FIXTURES/uv-cutoff" ;;
    -o) cp "$FIXTURES/lock" "$2" ;;
  esac
  shift
done
STUB
chmod +x "$root/bin/"*
CUTOFF=$(date -u -d 2026-09-01T00:00:00Z +%s)
UV_CUTOFF=$(date -u -d "@$CUTOFF" +%Y-%m-%dT%H:%M:%SZ)
export PATH=$root/bin:$PATH FIXTURES=$fixtures CUTOFF UV_CUTOFF
old=2026-08-01T00:00:00Z
new=2026-09-20T00:00:00Z
commit_of() { printf "$1%.0s" {1..40}; } # digit
cur=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
c1=$(commit_of 1) c2=$(commit_of 2) c3=$(commit_of 3) c5=$(commit_of 5)

# asset
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
releases() { # entries...
  local IFS=,
  echo "[$*]"
}
releases "$(listed v9.0.0 true false "$old")" \
  "$(listed v8.0.0 false true "$old")" \
  "$(listed v3.0.0-rc1 false false "$old")" \
  "$(listed nightly false false "$old")" \
  "$(listed v2.1.0 false false "$new")" \
  "$(listed v2.0.0 false false "$old")" \
  "$(listed v1.3.0 false false "$old")" \
  | serve 'repos/example/demo/releases?per_page=100'
release v2.0.0 "$new" "$sha_a" | serve repos/example/demo/releases/tags/v2.0.0
release v1.3.0 "$old" "$sha_a" | serve repos/example/demo/releases/tags/v1.3.0
printf 'x86 bytes' | serve https://dl/v1.3.0/a
printf 'arm bytes' | serve https://dl/v1.3.0/b

asset() { lookup_asset "$pins" demo; }
expect "an asset lookup skips drafts, prereleases and recent releases" 0 \
  "candidate v1.3.0" asset
expect_not "and rc or labelled tags" "v3.0.0-rc1" asset
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

echo 'HTTP 502' | serve 'repos/example/demo/releases?per_page=100'
expect "a failed release listing fails the lookup" 1 "can't list" asset
releases "$(listed v2.1.0 false false "$new")" \
  | serve 'repos/example/demo/releases?per_page=100'
expect_not "a repo whose releases are all recent has no candidate" \
  candidate asset

# branch-commit: the newest aged push still on the branch wins.
echo '{"default_branch": "main"}' | serve repos/example/tool
serve 'repos/example/tool/activity?ref=main&per_page=100' <<EOF
[{"activity_type": "push", "timestamp": "$new", "after": "$c1"},
 {"activity_type": "push", "timestamp": "$old", "after": "$c5"},
 {"activity_type": "force_push", "timestamp": "$old", "after": "$c2"},
 {"activity_type": "branch_creation", "timestamp": "$old", "after": "$c3"},
 {"activity_type": "pr_merge", "timestamp": "$old", "after": "$c3"}]
EOF
echo 'HTTP 404' | serve "repos/example/tool/compare/$c5...main"
echo '{"status": "diverged"}' | serve "repos/example/tool/compare/$c2...main"
echo '{"status": "ahead"}' | serve "repos/example/tool/compare/$c3...main"
echo '{"status": "ahead"}' | serve "repos/example/tool/compare/$cur...$c3"
branch() { lookup_branch_commit "$pins" tool; }
expect "a branch commit skips recent, collected and force-pushed-away pushes" \
  0 "set TOOL_COMMIT $c3" branch
echo '{"status": "behind"}' | serve "repos/example/tool/compare/$cur...$c3"
expect_not "a branch commit behind the pin isn't proposed" candidate branch
echo '{"status": "diverged"}' | serve "repos/example/tool/compare/$cur...$c3"
expect "a pin no longer on the branch fails" 1 "isn't on" branch
echo 'HTTP 404' | serve "repos/example/tool/compare/$cur...$c3"
expect "a pin the repo doesn't have fails" 1 "doesn't have the pinned" branch
echo 'HTTP 502' | serve "repos/example/tool/compare/$cur...$c3"
expect "a compare error fails the lookup, not reads as up to date" 1 \
  "can't compare" branch
echo '{"status": "ahead"}' | serve "repos/example/tool/compare/$cur...$c3"
echo 'HTTP 502' | serve "repos/example/tool/compare/$c3...main"
expect "a compare error on a candidate fails the lookup" 1 "can't compare" \
  branch
echo '{"status": "diverged"}' | serve "repos/example/tool/compare/$c3...main"
expect "no aged commit still on the branch fails" 1 "days ago is still there" \
  branch
echo '{"status": "ahead"}' | serve "repos/example/tool/compare/$c3...main"

# tag-commit: a release's tag, once its commit is in an aged push.
t1=$(commit_of 6) t2=$(commit_of 7) t3=$(commit_of 8) tag_obj=$(commit_of 9)
tagged=$root/tagged.sh
{
  echo '# pin tag-commit tagged repo=example/tagged'
  echo "TAGGED_TAG='v1.0.0'"
  echo "TAGGED_COMMIT='$cur'"
} >"$tagged"
echo '{"default_branch": "main"}' | serve repos/example/tagged
printf '[{"activity_type": "push", "timestamp": "%s", "after": "%s"}]' \
  "$old" "$t2" | serve 'repos/example/tagged/activity?ref=main&per_page=100'
echo '{"status": "identical"}' | serve "repos/example/tagged/compare/$t2...main"
releases "$(listed v2.0.0 false false "$new")" \
  "$(listed v1.2.0 false false "$old")" "$(listed v1.1.0 false false "$old")" \
  | serve 'repos/example/tagged/releases?per_page=100'
echo "{\"object\": {\"type\": \"tag\", \"sha\": \"$tag_obj\"}}" \
  | serve repos/example/tagged/git/ref/tags/v1.2.0
echo "{\"object\": {\"type\": \"commit\", \"sha\": \"$t2\"}}" \
  | serve "repos/example/tagged/git/tags/$tag_obj"
echo '{"status": "identical"}' | serve "repos/example/tagged/compare/$t2...$t2"
echo '{"status": "ahead"}' | serve "repos/example/tagged/compare/$cur...$t2"
tag_lookup() { lookup_tag_commit "$tagged" tagged; }
expect "a tag-commit pin follows an annotated tag to its commit" 0 \
  "set TAGGED_COMMIT $t2" tag_lookup
expect "and writes the tag" 0 "set TAGGED_TAG v1.2.0" tag_lookup
echo "{\"object\": {\"type\": \"commit\", \"sha\": \"$t3\"}}" \
  | serve "repos/example/tagged/git/tags/$tag_obj"
echo '{"status": "behind"}' | serve "repos/example/tagged/compare/$t3...$t2"
echo "{\"object\": {\"type\": \"commit\", \"sha\": \"$t1\"}}" \
  | serve repos/example/tagged/git/ref/tags/v1.1.0
echo '{"status": "ahead"}' | serve "repos/example/tagged/compare/$t1...$t2"
echo '{"status": "ahead"}' | serve "repos/example/tagged/compare/$cur...$t1"
expect "a tag on a commit no aged push holds waits for an older one" 0 \
  "candidate v1.1.0" tag_lookup
echo '{"status": "identical"}' | serve "repos/example/tagged/compare/$cur...$t1"
expect "a newer tag on the pinned commit is a candidate" 0 \
  "set TAGGED_TAG v1.1.0" tag_lookup
echo '{"status": "diverged"}' | serve "repos/example/tagged/compare/$cur...$t1"
expect "a tag that isn't ahead of the pin fails" 1 "isn't ahead" tag_lookup

# hf-model: the head revision, once its date is past the cooldown.
r1=$(commit_of 1) r2=$(commit_of 2)
lfs=$(printf 'f%.0s' {1..64})
model=$root/model.sh
{
  echo '# pin hf-model model model=org/m'
  echo "M_REVISION='$r1'"
  echo "M_FILE_CONFIG='config.json'"
  echo "M_SHA256_CONFIG='$ones'"
  echo "M_FILE_WEIGHTS='w.safetensors'"
  echo "M_SHA256_WEIGHTS='$twos'"
} >"$model"
hf=https://huggingface.co/api/models/org/m
hf_head() { # sha lastModified
  echo "{\"sha\": \"$1\", \"lastModified\": \"$2\"}" | serve "$hf"
}
hf_head "$r2" 2026-08-10T00:00:00.000Z
echo '{"lastModified": "2026-07-01T00:00:00.000Z"}' | serve "$hf/revision/$r1"
echo "[{\"path\": \"config.json\", \"oid\": \"x\"},
  {\"path\": \"w.safetensors\", \"lfs\": {\"oid\": \"$lfs\"}}]" \
  | serve "$hf/tree/$r2"
printf 'cfg' | serve "https://huggingface.co/org/m/resolve/$r2/config.json"
cfg_sum=$(printf 'cfg' | sha256sum | cut -d' ' -f1)
hf_lookup() { lookup_hf_model "$model" model; }
expect "a model takes the head revision" 0 "set M_REVISION $r2" hf_lookup
expect "an LFS file's digest comes from the listing" 0 \
  "set M_SHA256_WEIGHTS $lfs" hf_lookup
expect "a small file is downloaded and hashed" 0 \
  "set M_SHA256_CONFIG $cfg_sum" hf_lookup
hf_head "$r2" 2026-09-20T00:00:00.000Z
expect_not "a head inside the cooldown waits" candidate hf_lookup
hf_head "$r2" soon
expect "an unreadable date fails the lookup" 1 "can't read org/m's head" \
  hf_lookup

# node: the newest LTS release past the cooldown.
nodepins=$root/node.sh
{
  echo '# pin node node'
  echo "NODE_VERSION='v20.1.0'"
  echo "NODE_SHA256_X86_64='$ones'"
  echo "NODE_SHA256_AARCH64='$twos'"
} >"$nodepins"
serve https://nodejs.org/dist/index.json <<'EOF'
[{"version": "v22.1.0", "date": "2026-09-20", "lts": "Jod"},
 {"version": "v21.0.0", "date": "2026-08-01", "lts": false},
 {"version": "v20.2.0", "date": "2026-08-01", "lts": "Iron"}]
EOF
{
  echo "$ones  node-v20.2.0-linux-x64.tar.gz"
  echo "$twos  node-v20.2.0-linux-arm64.tar.gz"
} | serve https://nodejs.org/dist/v20.2.0/SHASUMS256.txt
node_lookup() { lookup_node "$nodepins" node; }
expect "node takes the newest aged LTS release" 0 "candidate v20.2.0" \
  node_lookup
expect "with each arch's digest from SHASUMS256.txt" 0 \
  "set NODE_SHA256_AARCH64 $twos" node_lookup
echo "$ones  node-v20.2.0-linux-x64.tar.gz" \
  | serve https://nodejs.org/dist/v20.2.0/SHASUMS256.txt
expect "a digest missing from SHASUMS256.txt fails" 1 "no sha256 for" \
  node_lookup
echo '<html>' | serve https://nodejs.org/dist/index.json
expect "an index that isn't JSON fails" 1 "can't read nodejs.org" node_lookup

# go: the newest stable release whose downloads are past the cooldown.
gopins=$root/go.sh
{
  echo '# pin go go'
  echo "GO_VERSION='1.20.1'"
  echo "GO_SHA256_X86_64='$ones'"
  echo "GO_SHA256_AARCH64='$twos'"
} >"$gopins"
go_files() { # version
  local arch
  for arch in amd64 arm64; do
    printf '{"filename": "go%s.linux-%s.tar.gz", "sha256": "%s"}\n' \
      "$1" "$arch" "$([ "$arch" = amd64 ] && echo "$ones" || echo "$twos")"
  done | jq -s .
}
jq -n --argjson a "$(go_files 1.21.0)" --argjson b "$(go_files 1.20.2)" \
  '[{version: "go1.22rc1", stable: false, files: []},
    {version: "go1.21.0", stable: true, files: $a},
    {version: "go1.20.2", stable: true, files: $b}]' \
  | serve 'https://go.dev/dl/?mode=json&include=all'
for f in go1.21.0.linux-amd64.tar.gz go1.21.0.linux-arm64.tar.gz; do
  echo 'Last-Modified: Sun, 20 Sep 2026 00:00:00 GMT' \
    | serve "HEAD https://dl.google.com/go/$f"
done
for f in go1.20.2.linux-amd64.tar.gz go1.20.2.linux-arm64.tar.gz; do
  echo 'Last-Modified: Sat, 01 Aug 2026 00:00:00 GMT' \
    | serve "HEAD https://dl.google.com/go/$f"
done
go_lookup() { lookup_go "$gopins" go; }
expect "go skips a release whose downloads are recent" 0 "candidate 1.20.2" \
  go_lookup
expect "with each arch's digest" 0 "set GO_SHA256_X86_64 $ones" go_lookup
echo 'Server: x' \
  | serve 'HEAD https://dl.google.com/go/go1.21.0.linux-amd64.tar.gz'
expect "a download with no Last-Modified fails" 1 "Last-Modified" go_lookup
echo '[]' | serve 'https://go.dev/dl/?mode=json&include=all'
expect "an empty release list fails" 1 "can't read go.dev" go_lookup

# uv-lock: kept only when something moved up and nothing moved down.
lockdir=$root/src/demo
mkdir -p "$lockdir"
{
  echo '# pin uv-lock semble lock=lock.txt input=semble.in'
  echo "SEMBLE_REQUIREMENTS='lock.txt'"
} >"$lockdir/pins.sh"
echo semble >"$lockdir/semble.in"
cat >"$lockdir/lock.txt" <<'EOF'
# header
semble==1.0.0 \
anyio==4.1.0 \
numpy==1.26.0 ; python_version < '3.13' \
numpy==2.1.0 ; python_version >= '3.13' \
EOF
uv_lock() { (cd "$root" && lookup_uv_lock src/demo/pins.sh semble); }
locked() { printf '%s \\\n' "$@" >"$fixtures/lock"; }
locked semble==1.1.0 anyio==4.1.0 "numpy==1.26.0 ; x" "numpy==2.1.0 ; y" \
  idna==3.0
expect "a lock with a requirement moved up is offered" 0 \
  "change semble: 1.0.0 → 1.1.0" uv_lock
expect "with an added requirement listed" 0 "change idna: added 3.0" uv_lock
expect_not "and a name pinned twice by markers left alone" "change numpy" \
  uv_lock
locked semble==1.1.0 AnyIO==4.0.0 "numpy==1.26.0 ; x" "numpy==2.1.0 ; y"
expect_not "a lock with a requirement moved down isn't offered" candidate \
  uv_lock
expect "and says why" 0 "note keeps the committed lock: it would move anyio" \
  uv_lock
locked semble==1.0.0 anyio==4.1.0 "numpy==1.26.0 ; x" "numpy==2.1.0 ; y"
expect_not "an unchanged lock isn't" candidate uv_lock
expect "max_version keeps a local version whole" 0 2.1.0+cpu \
  max_version '2.1.0|2.1.0+cpu'
expect "and ranks a release above its candidate" 0 "" \
  test "$(max_version '1.0rc1|1.0')" = 1.0

# --- Outages, hostile values and other lookup edges ---------------------------

expect "a lookup fetches over HTTPS only, bounded in time and size" 0 "" \
  grep -q -e '-fsSL --proto =https --proto-redir =https --max-time' \
  "$fixtures/curl-args"
expect "with a size cap" 0 "--max-filesize" cat "$fixtures/curl-args"

expect "version_gt ranks a release candidate below its release" 1 "" \
  version_gt 1.0rc1 1.0
expect "and a dev release below an alpha" 0 "" version_gt 1.0a1 1.0.dev1
expect "and a post release above its release" 0 "" version_gt 1.0.post1 1.0

# A 502 on the newest aged push must fail, not fall back to an older one.
serve 'repos/example/tool/activity?ref=main&per_page=100' <<EOF
[{"activity_type": "push", "timestamp": "$old", "after": "$c5"},
 {"activity_type": "push", "timestamp": "$old", "after": "$c3"}]
EOF
echo 'HTTP 502' | serve "repos/example/tool/compare/$c5...main"
expect "an outage on the newest aged push fails the lookup" 1 \
  "can't compare" branch
branch_quiet() { branch 2>/dev/null || true; }
expect_not "with nothing to write" "set TOOL" branch_quiet
echo 'HTTP 404' | serve "repos/example/tool/compare/$c5...main"
cp "$pins" "$root/at-head.sh"
pin_set "$root/at-head.sh" TOOL_COMMIT "$c3"
expect_not "a pin already at the aged head stays quiet" candidate \
  lookup_branch_commit "$root/at-head.sh" tool

# A 502 on a tag's compare must fail, not fall back to an older tag.
echo "{\"object\": {\"type\": \"commit\", \"sha\": \"$t2\"}}" \
  | serve repos/example/tagged/git/ref/tags/v1.2.0
echo 'HTTP 502' | serve "repos/example/tagged/compare/$t2...$t2"
# The older tag is good, so falling back to it would print a candidate.
echo '{"status": "ahead"}' | serve "repos/example/tagged/compare/$cur...$t1"
expect "an outage on a tag's compare fails the lookup" 1 "can't compare" \
  tag_lookup
tag_quiet() { tag_lookup 2>/dev/null || true; }
expect_not "rather than fall back to an older tag" candidate tag_quiet
echo '{"status": "identical"}' | serve "repos/example/tagged/compare/$t2...$t2"
echo 'HTTP 502' | serve "repos/example/tagged/compare/$cur...$t2"
expect "an outage comparing the pin with a tag fails the lookup" 1 \
  "can't compare" tag_lookup
expect_not "with no candidate" candidate tag_quiet

# Hostile upstream values never reach pins.sh.
hostile_sha="$(printf 'z%.0s' {1..64})"
release v1.3.0 "$old" "$hostile_sha" \
  | serve repos/example/demo/releases/tags/v1.3.0
releases "$(listed "v1.3.0'" false false "$old")" \
  "$(listed v1.3.0 false false "$old")" \
  | serve 'repos/example/demo/releases?per_page=100'
expect "a malformed digest from GitHub fails the lookup" 1 "malformed" \
  dry_asset
release v1.3.0 "$old" "$sha_a" | serve repos/example/demo/releases/tags/v1.3.0
expect_not "and a tag with a quote is never considered" "v1.3.0'" asset
echo "{\"object\": {\"type\": \"commit\", \"sha\": \"../$t2\"}}" \
  | serve repos/example/tagged/git/ref/tags/v1.2.0
expect "a malformed commit behind a tag fails the lookup" 1 \
  "can't resolve" tag_lookup
hf_head "$r2" 2026-08-10T00:00:00.000Z
echo "[{\"path\": \"config.json\", \"oid\": \"x\"},
  {\"path\": \"w.safetensors\", \"lfs\": {\"oid\": \"$hostile_sha\"}}]" \
  | serve "$hf/tree/$r2"
expect "a malformed model digest fails the lookup" 1 "malformed" hf_lookup
serve https://nodejs.org/dist/index.json <<'EOF'
[{"version": "v20.2.0", "date": "2026-08-01", "lts": "Iron"}]
EOF
{
  echo "$hostile_sha  node-v20.2.0-linux-x64.tar.gz"
  echo "$twos  node-v20.2.0-linux-arm64.tar.gz"
} | serve https://nodejs.org/dist/v20.2.0/SHASUMS256.txt
expect "a malformed Node digest fails the lookup" 1 "no sha256" node_lookup

cp "$pins" "$root/odd.sh"
pin_set "$root/odd.sh" DEMO_ASSET_X86_64 'demo {version}.tar.gz'
expect "a template that expands to a bad name fails the lookup" 1 \
  "to a bad name" lookup_asset "$root/odd.sh" demo

# The model's date check: a head older than the pin isn't proposed.
echo "[{\"path\": \"config.json\", \"oid\": \"x\"},
  {\"path\": \"w.safetensors\", \"lfs\": {\"oid\": \"$lfs\"}}]" \
  | serve "$hf/tree/$r2"
echo '{"lastModified": "2026-08-20T00:00:00.000Z"}' \
  | serve "$hf/revision/$r1"
expect_not "a model head older than the pinned revision waits" candidate \
  hf_lookup

# A pin missing its digests fails rather than bumping only the version.
for kind in node go; do
  upper=$(tr '[:lower:]' '[:upper:]' <<<"$kind")
  {
    echo "# pin $kind $kind"
    echo "${upper}_VERSION='v1.0.0'"
  } >"$root/bare-$kind.sh"
  expect "a $kind pin without digests fails" 1 "no $kind's digests" \
    "lookup_$kind" "$root/bare-$kind.sh" "$kind"
done
{
  echo '# pin hf-model model model=org/m'
  echo "M_REVISION='$r1'"
} >"$root/bare-model.sh"
expect "a model pin without files fails" 1 "no model's files" \
  lookup_hf_model "$root/bare-model.sh" model

# uv-lock: the compile runs with the cutoff, and a failed compile fails.
printf '%s \\\n' "torch==2.1.0 ; x" "torch==2.1.0+cpu ; y" \
  >>"$lockdir/lock.txt"
locked semble==1.0.0 anyio==4.1.0 "numpy==1.26.0 ; x" "numpy==2.1.0 ; y" \
  "torch==2.2.0 ; x" "torch==2.2.0+cpu ; y"
expect "a local version moving up is offered" 0 \
  "change torch: 2.1.0/2.1.0+cpu → 2.2.0/2.2.0+cpu" uv_lock
expect "from its versions joined by /" 0 "torch==2.1.0/2.1.0+cpu" uv_lock
expect "to its versions joined by /" 0 "torch==2.2.0/2.2.0+cpu" uv_lock
mkdir -p "$root/globs" && touch "$root/globs/5.0"
glob_max() { (cd "$root/globs" && max_version '1.0|[5].0'); }
expect_not "max_version never globs a version" 5.0 glob_max
locked semble==1.1.0 anyio==4.1.0 "numpy==1.26.0 ; x" "numpy==2.1.0 ; y" \
  "torch==2.1.0 ; x" "torch==2.1.0+cpu ; y"
uv_lock >/dev/null
expect "the lock compiles up to the cutoff" 0 "$UV_CUTOFF" \
  cat "$fixtures/uv-cutoff"
touch "$fixtures/uv-fails"
expect "a failed compile fails the lookup" 1 "uv pip compile failed" uv_lock
rm "$fixtures/uv-fails"

# Dry runs over small repos of their own.
dry_repo() { # pins.sh lines...
  local dir
  dir=$(mktemp -d "$root/dry.XXXX")
  mkdir -p "$dir/src/odd"
  echo '{"id": "odd", "version": "1.0.0"}' \
    >"$dir/src/odd/devcontainer-feature.json"
  printf '%s\n' "$@" >"$dir/src/odd/pins.sh"
  echo "$dir"
}
dry_in() { (cd "$1" && "$scripts/pin-bumps.sh" --dry-run); }
two=$(dry_repo '# pin branch-commit tool repo=example/tool' \
  "TOOL_COMMIT='$cur'" '' '# pin branch-commit tool2 repo=example/tool' \
  "TOOL2_COMMIT='$cur'")
# Both lookups fail on the fixtures here; tool2 being looked up at all is
# the point.
expect "a lookup can't eat the list of pins" 1 "odd tool2 (branch-commit)" \
  env STUB_EATS_STDIN=1 bash -c "cd '$two' && '$scripts/pin-bumps.sh' --dry-run"
expect "a dry run with a failed lookup exits 1" 1 "lookup failed" \
  dry_in "$(dry_repo '# pin branch-commit gone repo=example/gone' \
    "GONE_COMMIT='$cur'")"
expect "an unknown pin kind fails the dry run" 1 "unknown pin kind weird" \
  dry_in "$(dry_repo '# pin weird odd')"
expect "a kind named after a helper is unknown too" 1 "unknown pin kind pin" \
  dry_in "$(dry_repo '# pin pin odd')"
empty=$(mktemp -d "$root/empty.XXXX")
mkdir -p "$empty/src"
expect "a run that finds no Features fails" 1 "no Features under src" \
  dry_in "$empty"
expect "a malformed header fails the dry run" 1 "malformed # pin header" \
  dry_in "$(dry_repo '# pin asset')"
expect "a pins.sh with no pins fails the dry run" 1 "has no # pin header" \
  dry_in "$(dry_repo '# just a comment')"

# Every real tool name is unique, since issues are titled by tool.
expect "no two pins share a tool name" 0 "" test -z "$(for f in \
  "$repo"/src/*/pins.sh; do pin_list "$f"; done | awk '{ print $2 }' \
  | sort | uniq -d)"

# --- End to end, against a local remote and a stub GitHub ---------------------

# The remote is a bare repo. The stub gh keeps pull requests in $PRS, serves
# them newest first (so the script must sort them), insists on the
# owner-qualified head query and a main base, reads a PR's commit authors
# from the remote's branch as GitHub would, and serves everything else from
# fixtures.
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
  "GET $pulls?head=example:pin-bumps/demo&state=all&per_page=100")
    # A competing push, once, after the script's fetch and before its push.
    if [ -f "${RACE:-}" ]; then
      rm "$RACE"
      git -C "$HAND" push -q origin HEAD:pin-bumps/demo
    fi
    jq reverse "$PRS" | out
    ;;
  "GET $pulls?"*) echo "stub gh: unexpected query $path" >&2 && exit 1 ;;
  "POST $pulls")
    jq -e '.base == "main" and .head == "pin-bumps/demo"' "$input" \
      >/dev/null || { echo "stub gh: bad PR $(cat "$input")" >&2 && exit 1; }
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
printf '{\n  "id": "demo",\n  "version": "1.0.0"\n}\n' \
  >"$seed/src/demo/devcontainer-feature.json"
printf '## 1.0.0\n\n- First release.\n' >"$seed/src/demo/CHANGELOG.md"
{
  echo '# pin branch-commit tool repo=example/tool'
  echo "TOOL_COMMIT='$cur'"
} >"$seed/src/demo/pins.sh"
commit_seed() { # message
  git -C "$seed" add -A
  git -C "$seed" -c user.name=t -c user.email=t@t commit -qm "$1"
}
commit_seed seed
git clone -q --bare "$seed" "$origin"
git -C "$seed" remote add origin "$origin"
run=$root/run
git clone -q "$origin" "$run"

# The tool's newest aged commit, dated from now: the script sets its own
# cutoff.
aged_at=$(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%SZ)
recent_at=$(date -u -d '3 days ago' +%Y-%m-%dT%H:%M:%SZ)
# A push 3 days old comes first, so a run that ignored its cooldown would
# propose c1.
tool_head() { # commit
  echo "[{\"activity_type\": \"push\", \"timestamp\": \"$recent_at\",
    \"after\": \"$c1\"},
    {\"activity_type\": \"push\", \"timestamp\": \"$aged_at\",
    \"after\": \"$1\"}]" \
    | serve 'repos/example/tool/activity?ref=main&per_page=100'
  echo '{"status": "ahead"}' | serve "repos/example/tool/compare/$1...main"
  echo '{"status": "ahead"}' | serve "repos/example/tool/compare/$cur...$1"
}

bump() {
  (cd "$run" && PATH=$root/e2e-bin:$PATH GH_TOKEN=token APP_SLUG=pinbot \
    GITHUB_REPOSITORY=example/repo "$scripts/pin-bumps.sh" \
    --report "$root/report")
}
remote_file() { git -C "$origin" show "pin-bumps/demo:src/demo/$1"; }
pr() { jq -r ".[] | select(.number == $1) | .$2" "$PRS"; }
pr_count() { jq length "$PRS"; }
branch_is() { # rev
  test "$(git -C "$origin" rev-parse pin-bumps/demo)" \
    = "$(git -C "$origin" rev-parse "$1")"
}
parent_is() { # rev
  test "$(git -C "$origin" rev-parse pin-bumps/demo^)" \
    = "$(git -C "$origin" rev-parse "$1")"
}
set_pr() { # number jq-update
  jq --argjson n "$1" "map(if .number == \$n then $2 else . end)" "$PRS" \
    >"$PRS.tmp" && mv "$PRS.tmp" "$PRS"
}
# Runs the release checks against the branch, as its PR's CI would.
release_checks() {
  local clone=$root/check
  rm -rf "$clone"
  git clone -q -b pin-bumps/demo "$origin" "$clone"
  (cd "$clone" && "$scripts/check-versions.sh" "$(git rev-parse origin/main)")
}

dry() {
  (cd "$run" && PATH=$root/e2e-bin:$PATH GITHUB_REPOSITORY=example/repo \
    "$scripts/pin-bumps.sh" --dry-run)
}
tool_head "$c3"
expect "a dry run shows the candidate past the cooldown" 0 \
  "demo tool (branch-commit): aaaaaaaaaaaa -> 333333333333" dry
expect "and opens no PR" 0 "" test "$(pr_count)" = 0
expect "and pushes no branch" 1 "" \
  git -C "$origin" rev-parse -q --verify pin-bumps/demo
expect "a newer pin opens a PR" 0 "demo: opened #1" bump
expect "the branch holds the new pin" 0 "TOOL_COMMIT='$c3'" remote_file pins.sh
expect "the branch raises the minor version" 0 '"version": "1.1.0"' \
  remote_file devcontainer-feature.json
expect "the changelog entry lists the bump" 0 \
  "- \`tool\`: aaaaaaaaaaaa → 333333333333" remote_file CHANGELOG.md
expect "the branch passes the version check" 0 "" release_checks
expect "the commit is the App's" 0 \
  "42+pinbot[bot]@users.noreply.github.com" \
  git -C "$origin" log -1 --format=%ae pin-bumps/demo
expect "the PR holds the version" 0 "held: tool@$c3" pr 1 body
expect "the report has the lookup" 0 "$(printf 'lookup\ttool\tok')" \
  cat "$root/report"

head=$(git -C "$origin" rev-parse pin-bumps/demo)
expect "an unchanged rerun pushes nothing" 0 "pin-bumps/demo unchanged" bump
expect "and keeps the branch" 0 "" branch_is "$head"
expect "and opens no second PR" 0 "" test "$(pr_count)" = 1

# Only a workflow moving on main leaves the branch on its parent.
mkdir -p "$seed/.github/workflows"
echo 'name: x' >"$seed/.github/workflows/x.yml"
commit_seed workflow
git -C "$seed" push -q origin HEAD:main
expect "a workflow change on main leaves the branch where it is" 0 \
  "pin-bumps/demo unchanged" bump
expect "on its old parent" 0 "" branch_is "$head"

# A newer version while the PR is open updates it in place.
c4=$(commit_of 4)
tool_head "$c4"
expect "a newer version updates the open PR" 0 "demo: updated #1" bump
expect "with the new version held" 0 "held: tool@$c4" pr 1 body
expect "and no second PR" 0 "" test "$(pr_count)" = 1
set_pr 1 '.title = "edited"'
expect "a drifted title is put back" 0 "demo: updated #1" bump
expect "to the workflow's" 0 "chore(demo): bump pinned tools" pr 1 title
expect_not "and an unchanged PR isn't touched" "updated" bump

# A failed lookup leaves the branch and PR alone.
head=$(git -C "$origin" rev-parse pin-bumps/demo)
body_before=$(pr 1 body)
echo 'HTTP 502' | serve "repos/example/tool/compare/$cur...$c4"
expect "a failed lookup reports" 0 "lookup failed" bump
expect "and leaves the branch" 0 "" branch_is "$head"
expect "and the PR" 0 "" test "$(pr 1 body)" = "$body_before"
expect "and the report says so" 0 "$(printf 'lookup\ttool\tfail')" \
  cat "$root/report"
echo '{"status": "ahead"}' | serve "repos/example/tool/compare/$cur...$c4"

# A hand edit stops the rebuilds; Not applied lists only what's newer than
# the branch holds.
hand=$root/hand
git clone -q -b pin-bumps/demo "$origin" "$hand"
echo note >"$hand/src/demo/NOTES.md"
git -C "$hand" add -A
git -C "$hand" -c user.name=me -c user.email=me@example.com commit -qm hand
git -C "$hand" push -q origin pin-bumps/demo
hand_head=$(git -C "$origin" rev-parse pin-bumps/demo)
expect "a hand-edited branch isn't rebuilt" 0 "" bump
expect "and keeps its head" 0 "" branch_is "$hand_head"
expect_not "and isn't told it lacks the version it holds" "Not applied" \
  pr 1 body
c5=$(commit_of 5)
tool_head "$c5"
bump >/dev/null 2>&1
expect "a newer version is listed as not applied" 0 \
  "Not applied: \`tool@$c5\`" pr 1 body
expect "and the branch still isn't rebuilt" 0 "" branch_is "$hand_head"

# Closing a PR unmerged excludes the versions it held.
set_pr 1 '.state = "closed"'
tool_head "$c4"
expect_not "a version from a PR closed unmerged isn't proposed again" \
  opened bump
tool_head "$c5"
expect "a newer version is" 0 "demo: opened #2" bump
expect "rebuilt from main, past the hand edit" 0 "" parent_is main
expect "with the closed PR's version excluded" 0 "Excluded: \`tool@$c4\`" \
  pr 2 body

# Exclusions carry over generations of PRs.
set_pr 2 '.state = "closed"'
c6=$(commit_of 6)
tool_head "$c6"
expect "after two unmerged closes" 0 "demo: opened #3" bump
expect "both versions stay excluded" 0 \
  "Excluded: \`tool@$c4\`, \`tool@$c5\`" pr 3 body

# The script's own close excludes nothing.
echo '{"status": "behind"}' | serve "repos/example/tool/compare/$cur...$c6"
expect "nothing newer closes the PR" 0 "closed #3" bump
expect "which is closed" 0 closed pr 3 state
expect_not "without its held line" "held:" pr 3 body
echo '{"status": "ahead"}' | serve "repos/example/tool/compare/$cur...$c6"
expect "so its version is proposed again" 0 "demo: opened #4" bump
expect "and the exclusions carry on" 0 "Excluded: \`tool@$c4\`, \`tool@$c5\`" \
  pr 4 body

# A PR body edited on GitHub can come back with CRLF line endings.
set_pr 4 '.body |= (sub("Excluded: [^\n]*"; "Excluded: `tool@'"$c4"'`")
  | gsub("\n"; "\r\n"))'
expect "an edited CRLF body is read" 0 "" bump
expect "and its last excluded version kept" 0 "Excluded: \`tool@$c4\`" pr 4 body
expect_not "and the deleted one allowed again" "tool@$c5\`" pr 4 body

# A rejected push leaves the branch and PR alone, and is reported.
head=$(git -C "$origin" rev-parse pin-bumps/demo)
body_before=$(pr 4 body)
cat >"$origin/hooks/pre-receive" <<'HOOK'
#!/bin/sh
echo 'refusing to allow a GitHub App to create or update workflow' \
  '`.github/workflows/x.yml` without `workflows` permission' >&2
exit 1
HOOK
chmod +x "$origin/hooks/pre-receive"
c7=$(commit_of 7)
tool_head "$c7"
expect "a rejected push is reported" 0 "push refused: remote: refusing" bump
expect "in the report" 0 "$(printf 'push\tdemo\trefused')" cat "$root/report"
expect_not "with no ok row to close its issue" "$(printf 'push\tdemo\tok')" \
  cat "$root/report"
expect "the branch stays" 0 "" branch_is "$head"
expect "and the PR" 0 "" test "$(pr 4 body)" = "$body_before"
rm "$origin/hooks/pre-receive"

# The Feature moving on main moves the branch onto it.
echo docs >"$seed/src/demo/README.md"
commit_seed docs
git -C "$seed" push -q origin HEAD:main
expect "a Feature that moved on main moves its branch" 0 \
  "pushed pin-bumps/demo" bump
expect "onto main" 0 "" parent_is main
expect "and still passes the version check" 0 "" release_checks

# A merged PR excludes nothing it held.
set_pr 4 '.state = "closed" | .merged_at = "2026-10-03T00:00:00Z"'
expect "after a merged PR its versions can be proposed again" 0 \
  "demo: opened #5" bump
expect "and the exclusions carry on" 0 "Excluded: \`tool@$c4\`" pr 5 body

# A branch left over from a closed PR is rebuilt on main.
set_pr 5 '.state = "closed"'
echo 'name: y' >"$seed/.github/workflows/y.yml"
commit_seed workflow2
git -C "$seed" push -q origin HEAD:main
c8=$(commit_of 8)
tool_head "$c8"
expect "a newer version after a close opens a PR" 0 "demo: opened #6" bump
expect "rebuilt on main, past the workflow change" 0 "" parent_is main

# One Feature's error fails the run only after the others had their turn.
mkdir -p "$seed/src/aaa"
cp "$seed/src/demo/devcontainer-feature.json" "$seed/src/demo/CHANGELOG.md" \
  "$seed/src/demo/pins.sh" "$seed/src/aaa/"
commit_seed aaa
git -C "$seed" push -q origin HEAD:main
aaa_out=$(bump 2>&1)
aaa_rc=$?
expect "a Feature that errors fails the run" 0 "" test "$aaa_rc" = 1
expect "naming it" 0 "::error::aaa" echo "$aaa_out"
expect "after the next Feature had its turn" 0 "demo: pin-bumps/demo" \
  echo "$aaa_out"

# A push landing between the script's fetch and its own loses nothing: the
# lease refuses the script's.
git -C "$seed" rm -q -r src/aaa
commit_seed "drop aaa"
git -C "$seed" push -q origin HEAD:main
git -C "$hand" fetch -q origin
git -C "$hand" reset -q --hard origin/pin-bumps/demo
echo race >"$hand/src/demo/RACE.md"
git -C "$hand" add -A
# The App's own identity, so the script rebuilds rather than defers.
git -C "$hand" -c user.name='pinbot[bot]' \
  -c user.email='42+pinbot[bot]@users.noreply.github.com' commit -qm race
export RACE=$root/race HAND=$hand
touch "$RACE"
c9=$(commit_of 9)
tool_head "$c9"
race_head=$(git -C "$hand" rev-parse HEAD)
expect "a push racing another is refused" 0 "push refused" bump
expect "and the other push stands" 0 "" branch_is "$race_head"
expect_not "and the report has no ok row for it" \
  "$(printf 'push\tdemo\tok')" cat "$root/report"

# A pins.sh whose pin list can't be read is reported, and fails the run.
mkdir -p "$seed/src/zzz"
cp "$seed/src/demo/devcontainer-feature.json" "$seed/src/demo/CHANGELOG.md" \
  "$seed/src/zzz/"
echo '# pin asset' >"$seed/src/zzz/pins.sh"
commit_seed zzz
git -C "$seed" push -q origin HEAD:main
expect "a malformed pins.sh fails a real run" 1 "malformed # pin header" bump
expect "and is reported against it" 0 \
  "$(printf 'pins\tzzz\tfail')" cat "$root/report"
echo '# pin nosuch zzz-tool' >"$seed/src/zzz/pins.sh"
commit_seed "fix zzz"
git -C "$seed" push -q origin HEAD:main
expect "once it reads, the run passes" 0 "" bump
expect "and reports it clean" 0 \
  "$(printf 'pins\tzzz\tok')" cat "$root/report"

# --- The lock write path, end to end ------------------------------------------

# A Feature whose only pin is a uv lock, on a remote of its own.
export ORIGIN=$root/lock-origin.git PRS=$root/lock-prs.json
echo '[]' >"$PRS"
lockseed=$root/lockseed
git init -q -b main "$lockseed"
mkdir -p "$lockseed/src/demo"
printf '{\n  "id": "demo",\n  "version": "1.0.0"\n}\n' \
  >"$lockseed/src/demo/devcontainer-feature.json"
printf '## 1.0.0\n\n- First release.\n' >"$lockseed/src/demo/CHANGELOG.md"
{
  echo '# pin uv-lock semble lock=lock.txt input=semble.in'
  echo "SEMBLE_REQUIREMENTS='lock.txt'"
} >"$lockseed/src/demo/pins.sh"
echo semble >"$lockseed/src/demo/semble.in"
printf '# Regenerate with the documented command.\nsemble==1.0.0 \\\n' \
  >"$lockseed/src/demo/lock.txt"
git -C "$lockseed" add -A
git -C "$lockseed" -c user.name=t -c user.email=t@t commit -qm seed
git clone -q --bare "$lockseed" "$ORIGIN"
lockrun=$root/lockrun
git clone -q "$ORIGIN" "$lockrun"
locked semble==1.1.0
lock_bump() {
  (cd "$lockrun" && PATH=$root/e2e-bin:$PATH GH_TOKEN=token \
    APP_SLUG=pinbot GITHUB_REPOSITORY=example/repo "$scripts/pin-bumps.sh")
}
lock_file() { git -C "$ORIGIN" show "pin-bumps/demo:src/demo/$1"; }
expect "a newer lock opens a PR" 0 "demo: opened #1" lock_bump
expect "the lock keeps its header" 0 "" \
  test "$(lock_file lock.txt | sed -n 1p)" \
  = "# Regenerate with the documented command."
expect "under it, the regenerated lock" 0 "semble==1.1.0" lock_file lock.txt
expect "the changelog lists what moved" 0 "  - semble: 1.0.0 → 1.1.0" \
  lock_file CHANGELOG.md
expect "the compile ran with the run's cutoff" 0 \
  "$(date -u -d '7 days ago' +%Y-%m-%d)" cat "$fixtures/uv-cutoff"

# --- Tracking issues ----------------------------------------------------------

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
    cp "${!#}" "$ISSUES.body"
    ;;
  "issue edit")
    echo "edit $3" >>"$CALLS"
    cp "${!#}" "$ISSUES.body"
    ;;
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
expect "an unreadable pins.sh opens an issue" 0 \
  "create pin-bumps: zzz pins.sh unreadable" \
  issues "pins${tab}zzz${tab}fail${tab}no # pin header"
expect "a run that reads it closes it" 0 "close 3" \
  issues "pins${tab}zzz${tab}ok"

# shellcheck disable=SC2016 # Markdown backticks
issues "$(printf 'lookup\tzz\tfail\t`@someone` see')" >/dev/null
expect "upstream text in an issue sits in a code block" 0 '```text' \
  cat "$ISSUES.body"
# shellcheck disable=SC2016 # Markdown backticks
expect_not "without its backticks" '`@someone`' cat "$ISSUES.body"
long=$(printf 'x%.0s' {1..400})
issues "$(printf 'lookup\tzz\tfail\tbell\001esc\033%s' "$long")" >/dev/null
expect "an issue quotes at most 300 characters" 0 "" \
  test "$(sed -n '/^```text$/{n;p}' "$ISSUES.body" | wc -c)" -le 301
expect_not "and no control characters" $'\001' cat "$ISSUES.body"
expect_not "of any kind" $'\033' cat "$ISSUES.body"
expect "an unknown report row fails" 1 "unknown report row" \
  issues "$(printf 'lookup\tzz\tmaybe')"
expect "an unknown row kind fails even when ok" 1 "unknown report row" \
  issues "$(printf 'bogus\tzz\tok')"

summary
