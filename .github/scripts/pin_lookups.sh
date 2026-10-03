# shellcheck shell=bash
# One lookup per pin kind, for pin-bumps.sh. Each takes a pins.sh and a tool,
# and prints its findings as lines:
#   current <shown value>
#   release <tag> <asset names...>   (asset: the newest aged release seen)
#   candidate <shown value>          (only when a newer pin qualifies)
#   key <tool>@<value>               (the version, for Excluded: lists)
#   set <NAME> <value>               (each pins.sh value to write)
#   lock <path> <file>               (uv-lock: the regenerated lock)
#   change <text>                    (uv-lock: each moved requirement)
# A failed lookup prints its reason on stderr and returns 1. Every candidate
# is at least 7 days old by a server-side date: the caller sets CUTOFF (epoch
# seconds). DRY_RUN=1 downloads nothing. Needs pins_lib.sh.

# Succeeds when an ISO 8601 date is at or before CUTOFF.
aged() { # date
  local when
  when=$(date -u -d "$1" +%s 2>/dev/null) && [ "$when" -le "$CUTOFF" ]
}

# Prints the pin's variable prefix: its first NAME ending in suffix, without it.
pin_prefix() { # file tool suffix
  pin_vars "$1" "$2" | sed -n "s/^\([A-Z0-9_]*\)$3=.*/\1/p" | head -1
}

# Prints the arch keys (X86_64, AARCH64) of the pin's NAME_<arch> variables.
pin_arches() { # file tool stem
  pin_vars "$1" "$2" | sed -n "s/^$3_\([A-Z0-9_]*\)=.*/\1/p"
}

sha256_of_url() { # url
  local tmp sum
  tmp=$(mktemp) || return 1
  if curl -fsSL --retry 2 -o "$tmp" "$1"; then
    sum=$(sha256sum "$tmp" | cut -d' ' -f1)
  fi
  rm -f "$tmp"
  [ -n "${sum:-}" ] && echo "$sum"
}

# Prints the newest default-branch commit that was pushed at least 7 days ago
# and is still on the branch, from the server-timestamped activity log.
aged_branch_head() { # repo
  local branch at after status
  { branch=$(gh api "repos/$1" --jq .default_branch) \
    && valid name "$branch"; } \
    || { echo "can't read $1's default branch" >&2 && return 1; }
  while read -r at after; do
    { aged "$at" && valid commit "$after"; } || continue
    status=$(gh api "repos/$1/compare/$after...$branch" --jq .status) \
      || continue
    case $status in identical | ahead) echo "$after" && return 0 ;; esac
  done < <(gh api --paginate "repos/$1/activity?ref=$branch&per_page=100" \
    --jq '.[] | select(.activity_type == "push" or .activity_type ==
      "force_push" or .activity_type == "pr_merge" or .activity_type ==
      "merge_queue_merge") | "\(.timestamp) \(.after)"')
  echo "no commit on $1's $branch pushed 7 or more days ago is still there" >&2
  return 1
}

# Succeeds when GitHub's compare of base...head is one of the given statuses.
compare_is() { # repo base head status...
  local status
  status=$(gh api "repos/$1/compare/$2...$3" --jq .status) || return 1
  shift 3
  [[ " $* " == *" $status "* ]]
}

# Prints the commit a tag points at, through any annotated tags.
tag_commit() { # repo tag
  local type sha
  read -r type sha < <(gh api "repos/$1/git/ref/tags/$2" \
    --jq '.object | "\(.type) \(.sha)"') || return 1
  while [ "$type" = tag ]; do
    read -r type sha < <(gh api "repos/$1/git/tags/$sha" \
      --jq '.object | "\(.type) \(.sha)"') || return 1
  done
  [ "$type" = commit ] && echo "$sha"
}

# Prints the tags of releases that are neither drafts nor prereleases and
# were published at least 7 days ago, highest version first.
aged_release_tags() { # repo
  gh api "repos/$1/releases?per_page=100" --jq '.[]
    | select((.draft or .prerelease) | not) | "\(.published_at) \(.tag_name)"' \
    | while read -r at tag; do aged "$at" && echo "$tag"; done | sort -rV
}

lookup_asset() { # file tool
  local file=$1 tool=$2 repo prefix tag tags arches arch cand release
  local template name updated digest url sum names
  local -A urls digests
  repo=$(pin_attr "$file" "$tool" repo) \
    || { echo "its header has no repo=" >&2 && return 1; }
  prefix=$(pin_prefix "$file" "$tool" _TAG)
  tag=$(pin_get "$file" "${prefix}_TAG")
  arches=$(pin_arches "$file" "$tool" "${prefix}_ASSET")
  echo "current $tag"
  tags=$(aged_release_tags "$repo") \
    || { echo "can't list $repo's releases" >&2 && return 1; }
  for cand in $tags; do
    valid version "$cand" || continue
    release=$(gh api "repos/$repo/releases/tags/$cand") \
      || { echo "can't read $repo's release $cand" >&2 && return 1; }
    names=''
    for arch in $arches; do
      template=$(pin_get "$file" "${prefix}_ASSET_$arch")
      name=$(expand_asset "$template" "$cand")
      valid name "$name" \
        || { echo "$cand expands $template to a bad name" >&2 && return 1; }
      url=''
      read -r updated digest url < <(jq -r --arg n "$name" '.assets[]
        | select(.name == $n)
        | "\(.updated_at) \(.digest // "-") \(.browser_download_url)"' \
        <<<"$release")
      [ -n "${url:-}" ] || {
        echo "$repo's release $cand has no asset $name; update the template" >&2
        return 1
      }
      # An asset replaced in the last 7 days holds the release back.
      aged "$updated" || continue 2
      names+=" $name"
      urls[$arch]=$url
      digests[$arch]=${digest#sha256:}
    done
    echo "release $cand$names"
    version_gt "$cand" "$tag" || return 0
    echo "candidate $cand"
    echo "key $tool@$cand"
    echo "set ${prefix}_TAG $cand"
    for arch in $arches; do
      digest=${digests[$arch]}
      [ "$digest" != - ] || digest=''
      if [ "${DRY_RUN:-}" = 1 ]; then
        sum=${digest:-unhashed}
      else
        sum=$(sha256_of_url "${urls[$arch]}") \
          || { echo "can't download $cand's $arch asset" >&2 && return 1; }
        [ -z "$digest" ] || [ "$digest" = "$sum" ] || {
          echo "$cand's $arch asset doesn't match GitHub's digest" >&2
          return 1
        }
      fi
      [ "$sum" = unhashed ] || valid sha256 "$sum" || return 1
      echo "set ${prefix}_SHA256_$arch $sum"
    done
    return 0
  done
}

lookup_tag_commit() { # file tool
  local file=$1 tool=$2 repo prefix tag tags commit head cand sha
  repo=$(pin_attr "$file" "$tool" repo) \
    || { echo "its header has no repo=" >&2 && return 1; }
  prefix=$(pin_prefix "$file" "$tool" _TAG)
  tag=$(pin_get "$file" "${prefix}_TAG")
  commit=$(pin_get "$file" "${prefix}_COMMIT")
  echo "current $tag (${commit:0:12})"
  head=$(aged_branch_head "$repo") || return 1
  tags=$(aged_release_tags "$repo") \
    || { echo "can't list $repo's releases" >&2 && return 1; }
  for cand in $tags; do
    valid version "$cand" || continue
    version_gt "$cand" "$tag" || return 0
    { sha=$(tag_commit "$repo" "$cand") && valid commit "$sha"; } \
      || { echo "can't resolve $repo's tag $cand" >&2 && return 1; }
    # A tag re-pointed past the aged branch head waits for it.
    compare_is "$repo" "$sha" "$head" identical ahead || continue
    compare_is "$repo" "$commit" "$sha" ahead || {
      echo "$repo's tag $cand isn't ahead of the pinned commit" >&2
      return 1
    }
    echo "candidate $cand (${sha:0:12})"
    echo "key $tool@$cand"
    echo "set ${prefix}_TAG $cand"
    echo "set ${prefix}_COMMIT $sha"
    return 0
  done
}

lookup_branch_commit() { # file tool
  local file=$1 tool=$2 repo prefix commit head
  repo=$(pin_attr "$file" "$tool" repo) \
    || { echo "its header has no repo=" >&2 && return 1; }
  prefix=$(pin_prefix "$file" "$tool" _COMMIT)
  commit=$(pin_get "$file" "${prefix}_COMMIT")
  echo "current ${commit:0:12}"
  head=$(aged_branch_head "$repo") || return 1
  [ "$head" != "$commit" ] && compare_is "$repo" "$commit" "$head" ahead \
    || return 0
  echo "candidate ${head:0:12}"
  echo "key $tool@$head"
  echo "set ${prefix}_COMMIT $head"
}

lookup_hf_model() { # file tool
  local file=$1 tool=$2 model prefix revision api info sha modified current_mod
  local tree key name entry sum
  model=$(pin_attr "$file" "$tool" model) \
    || { echo "its header has no model=" >&2 && return 1; }
  prefix=$(pin_prefix "$file" "$tool" _REVISION)
  revision=$(pin_get "$file" "${prefix}_REVISION")
  echo "current ${revision:0:12}"
  api=https://huggingface.co/api/models/$model
  {
    info=$(curl -fsS --retry 2 "$api") \
      && read -r sha modified < <(jq -r '"\(.sha) \(.lastModified)"' \
        <<<"$info") \
      && valid commit "$sha"
  } || { echo "can't read $model's head" >&2 && return 1; }
  # Hugging Face dates a revision only by its commit, which the pusher sets.
  { [ "$sha" != "$revision" ] && aged "$modified"; } || return 0
  current_mod=$(curl -fsS --retry 2 "$api/revision/$revision" \
    | jq -r .lastModified) \
    || { echo "can't read $model's pinned revision" >&2 && return 1; }
  [ "$(date -u -d "$modified" +%s)" -gt "$(date -u -d "$current_mod" +%s)" ] \
    || return 0
  tree=$(curl -fsS --retry 2 "$api/tree/$sha") \
    || { echo "can't list $model's files at $sha" >&2 && return 1; }
  echo "candidate ${sha:0:12}"
  echo "key $tool@$sha"
  echo "set ${prefix}_REVISION $sha"
  for key in $(pin_arches "$file" "$tool" "${prefix}_FILE"); do
    name=$(pin_get "$file" "${prefix}_FILE_$key")
    entry=$(jq -r --arg p "$name" \
      '.[] | select(.path == $p) | .lfs.oid // "git"' <<<"$tree")
    [ -n "$entry" ] || { echo "$model has no $name at $sha" >&2 && return 1; }
    if [ "$entry" != git ]; then
      sum=$entry
    elif [ "${DRY_RUN:-}" = 1 ]; then
      sum=unhashed
    else
      sum=$(sha256_of_url "https://huggingface.co/$model/resolve/$sha/$name") \
        || { echo "can't download $model's $name" >&2 && return 1; }
    fi
    [ "$sum" = unhashed ] || valid sha256 "$sum" || return 1
    echo "set ${prefix}_SHA256_$key $sum"
  done
}

# Node's and Go's names for the pinned arches.
node_arch() { case $1 in X86_64) echo x64 ;; AARCH64) echo arm64 ;; esac }
go_arch() { case $1 in X86_64) echo amd64 ;; AARCH64) echo arm64 ;; esac }

lookup_node() { # file tool
  local file=$1 tool=$2 prefix version index cand sums arch name sum
  prefix=$(pin_prefix "$file" "$tool" _VERSION)
  version=$(pin_get "$file" "${prefix}_VERSION")
  echo "current $version"
  index=$(curl -fsS --retry 2 https://nodejs.org/dist/index.json) \
    || { echo "can't read nodejs.org's index" >&2 && return 1; }
  # The index dates a release by its files' timestamps; accepted (Pin updates).
  cand=$(jq -r '.[] | select(.lts != false) | "\(.date) \(.version)"' \
    <<<"$index" | while read -r at v; do aged "$at" && echo "$v"; done \
    | sort -rV | head -1)
  valid version "$cand" \
    || { echo "no LTS release in nodejs.org's index" >&2 && return 1; }
  version_gt "$cand" "$version" || return 0
  sums=$(curl -fsS --retry 2 "https://nodejs.org/dist/$cand/SHASUMS256.txt") \
    || { echo "can't read Node $cand's SHASUMS256.txt" >&2 && return 1; }
  echo "candidate $cand"
  echo "key $tool@$cand"
  echo "set ${prefix}_VERSION $cand"
  for arch in $(pin_arches "$file" "$tool" "${prefix}_SHA256"); do
    name=node-$cand-linux-$(node_arch "$arch").tar.gz
    sum=$(awk -v n="$name" '$2 == n { print $1 }' <<<"$sums")
    valid sha256 "$sum" \
      || { echo "SHASUMS256.txt has no $name" >&2 && return 1; }
    echo "set ${prefix}_SHA256_$arch $sum"
  done
}

lookup_go() { # file tool
  local file=$1 tool=$2 prefix version json cand arch name sum modified sets
  prefix=$(pin_prefix "$file" "$tool" _VERSION)
  version=$(pin_get "$file" "${prefix}_VERSION")
  echo "current $version"
  json=$(curl -fsS --retry 2 'https://go.dev/dl/?mode=json&include=all') \
    || { echo "can't read go.dev's release list" >&2 && return 1; }
  for cand in $(jq -r '.[] | select(.stable) | .version | ltrimstr("go")' \
    <<<"$json" | sort -rV); do
    valid version "$cand" || continue
    version_gt "$cand" "$version" || return 0
    sets=''
    for arch in $(pin_arches "$file" "$tool" "${prefix}_SHA256"); do
      name=go$cand.linux-$(go_arch "$arch").tar.gz
      sum=$(jq -r --arg n "$name" \
        '.[].files[] | select(.filename == $n) | .sha256' <<<"$json")
      valid sha256 "$sum" \
        || { echo "go.dev lists no sha256 for $name" >&2 && return 1; }
      # go.dev dates releases only by the download's Last-Modified.
      modified=$(curl -fsSI --retry 2 "https://dl.google.com/go/$name" \
        | sed -n 's/^[Ll]ast-[Mm]odified: *//p' | tr -d '\r')
      aged "$modified" || continue 2
      sets+="set ${prefix}_SHA256_$arch $sum"$'\n'
    done
    echo "candidate $cand"
    echo "key $tool@$cand"
    echo "set ${prefix}_VERSION $cand"
    printf '%s' "$sets"
    return 0
  done
}

# Prints "name version" for each name==version in a requirements file.
lock_pins() { # file
  sed -n 's/^\([A-Za-z0-9._-]*\)==\([^ ;\\]*\).*/\1 \2/p' "$1" \
    | awk '{ name = tolower($1); gsub(/_/, "-", name); print name, $2 }' \
    | LC_ALL=C sort
}

# Regenerates the lock from its input with the 7-day cutoff, and offers it
# only when a requirement moved up and none moved down, so a fix that landed
# inside the cooldown is never rolled back. Run from the repository root.
lookup_uv_lock() { # file tool
  local file=$1 tool=$2 dir lock input new before name old version up=0
  local down=0
  local -a changes=()
  dir=src/$(basename "$(dirname "$file")")
  { lock=$dir/$(pin_attr "$file" "$tool" lock) \
    && input=$dir/$(pin_attr "$file" "$tool" input); } \
    || { echo "its header needs lock= and input=" >&2 && return 1; }
  echo "current $tool==$(lock_pins "$lock" | awk -v t="$tool" '$1 == t {
    print $2 }')"
  new=$(mktemp)
  before=$(date -u -d "@$CUTOFF" +%Y-%m-%dT%H:%M:%SZ)
  uv pip compile "$input" --universal --python-version 3.12 \
    --generate-hashes --no-build --upgrade --no-header --quiet \
    --exclude-newer "$before" -o "$new" \
    || { echo "uv pip compile failed" >&2 && rm -f "$new" && return 1; }
  while read -r name old version; do
    if version_gt "$version" "$old"; then
      up=1
    else
      down=1
    fi
    changes+=("$name: $old → $version")
  done < <(LC_ALL=C join <(lock_pins "$lock") <(lock_pins "$new") \
    | awk '$2 != $3')
  if [ "$up" = 0 ] || [ "$down" = 1 ]; then
    rm -f "$new"
    return 0
  fi
  version=$(lock_pins "$new" | awk -v t="$tool" '$1 == t { print $2 }')
  echo "candidate $tool==$version"
  echo "key $tool@lock-$(lock_pins "$new" | sha256sum | cut -c1-12)"
  echo "lock $lock $new"
  printf 'change %s\n' "${changes[@]}"
}
