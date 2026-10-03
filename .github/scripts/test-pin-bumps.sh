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
file=$FIXTURES/$(tr -c 'A-Za-z0-9\n' _ <<<"$path")
[ -f "$file" ] || { echo "stub gh: no fixture for $path" >&2 && exit 1; }
read -r first code _ <"$file"
[ "$first" != HTTP ] || { echo "gh: error (HTTP $code)" >&2 && exit 1; }
if [ -n "$filter" ]; then jq -r "$filter" "$file"; else cat "$file"; fi
STUB
cat >"$root/bin/curl" <<'STUB'
#!/bin/bash
# Stub curl: prints a URL's fixture, its headers with -I, or writes it with -o.
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
for flag in --universal --generate-hashes --no-build --no-header --upgrade \
  "--exclude-newer $UV_CUTOFF"; do
  [[ $args == *" $flag "* ]] || { echo "stub uv: no $flag" >&2 && exit 3; }
done
while [ "$#" -gt 0 ]; do
  [ "$1" = -o ] && cp "$FIXTURES/lock" "$2"
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
tool_head() { # commit
  echo "[{\"activity_type\": \"push\", \"timestamp\": \"$aged_at\",
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

tool_head "$c3"
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
bump >/dev/null
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

# shellcheck disable=SC2016 # Markdown backticks
issues "$(printf 'lookup\tzz\tfail\t`@someone` see')" >/dev/null
expect "upstream text in an issue sits in a code block" 0 '```text' \
  cat "$ISSUES.body"
# shellcheck disable=SC2016 # Markdown backticks
expect_not "without its backticks" '`@someone`' cat "$ISSUES.body"

summary
