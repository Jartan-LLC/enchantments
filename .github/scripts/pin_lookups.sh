# shellcheck shell=bash
# One lookup per pin kind, for pin-bumps.sh. Each takes a pins.sh and a tool,
# and prints its findings as lines (after the "tool <name>" line pin-bumps.sh
# writes first):
#   current <shown value>
#   release <tag> <asset names...>   (asset: the newest aged release seen)
#   candidate <shown value>          (only when a newer pin qualifies)
#   key <tool>@<value>               (the version, for Excluded: lists)
#   set <NAME> <value>               (each pins.sh value to write)
#   lock <path> <file>               (uv-lock: the regenerated lock)
#   from <text>                      (uv-lock: what moves, shown as From)
#   change <text>                    (uv-lock: each requirement that moved)
#   note <text>                      (why a newer version isn't offered)
# A lookup that can't tell whether a newer pin exists prints its reason on
# stderr and returns 1, so an outage never reads as "nothing newer". Every
# candidate is at least COOLDOWN_DAYS old by the date its upstream reports:
# a server's timestamp, except hf-model's and node's (see those
# lookups). The caller sets CUTOFF (epoch seconds), and calls each
# lookup where set -e is off, checking its status itself. DRY_RUN=1
# downloads no release asset or model file. Needs pins_lib.sh.

fail_lookup() { # reason...
  echo "$*" >&2
  return 1
}

# Prints a date's epoch seconds; fails on a date it can't read.
# An empty date would read as today's midnight.
epoch() { [ -n "$1" ] && date -u -d "$1" +%s 2>/dev/null; }

# HTTPS only, bounded in time and size.
fetch() {
  curl -fsSL --proto '=https' --proto-redir '=https' --max-time 300 \
    --max-filesize 1073741824 --retry 2 "$@"
}

# Fails when a value pins.sh should hold is empty.
need() { # name value
  [ -n "$2" ] || fail_lookup "pins.sh has no $1"
}

# Prints the pin's variable prefix: its first NAME ending in suffix, without it.
pin_prefix() { # file tool suffix
  pin_vars "$1" "$2" | sed -n "s/^\([A-Z0-9_]*\)$3=.*/\1/p" | sed -n 1p
}

# Prints the arch keys (X86_64, AARCH64) of the pin's NAME_<arch> variables.
pin_arches() { # file tool stem
  pin_vars "$1" "$2" | sed -n "s/^$3_\([A-Z0-9_]*\)=.*/\1/p"
}

sha256_of_url() { # url
  local tmp sum
  tmp=$(mktemp) || return 1
  if fetch -o "$tmp" "$1"; then
    sum=$(sha256sum "$tmp" | cut -d' ' -f1)
  fi
  rm -f "$tmp"
  [ -n "${sum:-}" ] && echo "$sum"
}

# Prints GitHub's compare status of base...head. Fails with 1 when GitHub
# doesn't know a commit (404), and 2, with a reason, on any other error.
compare_status() { # repo base head
  local out
  if out=$(gh api "repos/$1/compare/$2...$3" --jq .status 2>&1); then
    echo "$out"
    return 0
  fi
  grep -q 'HTTP 404' <<<"$out" && return 1
  fail_lookup "can't compare $2...$3 in $1: $(tail -n 1 <<<"$out")"
  return 2
}

# Prints the newest default-branch commit that was pushed at least
# COOLDOWN_DAYS ago and is still on the branch, from the activity log, whose
# timestamps are the server's.
aged_branch_head() { # repo
  local branch activity at after when status rc
  { branch=$(gh api "repos/$1" --jq .default_branch) \
    && valid name "$branch"; } \
    || {
      fail_lookup "can't read $1's default branch"
      return 1
    }
  activity=$(gh api --paginate "repos/$1/activity?ref=$branch&per_page=100" \
    --jq '.[] | select(.activity_type == "push" or .activity_type ==
      "force_push" or .activity_type == "pr_merge" or .activity_type ==
      "merge_queue_merge") | "\(.timestamp) \(.after)"') \
    || {
      fail_lookup "can't read $1's activity"
      return 1
    }
  while read -r at after; do
    [ -n "$at" ] || continue
    when=$(epoch "$at") \
      || {
        fail_lookup "$1's activity has an unreadable date"
        return 1
      }
    if [ "$when" -gt "$CUTOFF" ] || ! valid commit "$after"; then continue; fi
    rc=0
    status=$(compare_status "$1" "$after" "$branch") || rc=$?
    # A 404 is a commit force-pushed away and since collected.
    case $rc in 1) continue ;; 2) return 1 ;; esac
    case $status in identical | ahead) echo "$after" && return 0 ;; esac
  done <<<"$activity"
  fail_lookup "no commit on $1's $branch pushed $COOLDOWN_DAYS or more days" \
    "ago is still there"
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

# Prints the version tags of releases that are neither drafts nor
# prereleases and were published at least COOLDOWN_DAYS ago, highest first.
aged_release_tags() { # repo
  local listing at tag when
  listing=$(gh api "repos/$1/releases?per_page=100" --jq '.[]
    | select((.draft or .prerelease) | not)
    | "\(.published_at) \(.tag_name)"') \
    || {
      fail_lookup "can't list $1's releases"
      return 1
    }
  while read -r at tag; do
    [ -n "$at" ] || continue
    when=$(epoch "$at") \
      || {
        fail_lookup "$1's release $tag has an unreadable date"
        return 1
      }
    if [ "$when" -le "$CUTOFF" ] && numeric_version "$tag"; then
      echo "$tag"
    fi
  done <<<"$listing" | sort -rV
}

lookup_asset() { # file tool
  local file=$1 tool=$2 repo prefix tag tags arches arch cand release
  local template name updated digest url sum names when
  local -A urls digests
  repo=$(pin_attr "$file" "$tool" repo) \
    || {
      fail_lookup "its header has no repo="
      return 1
    }
  prefix=$(pin_prefix "$file" "$tool" _TAG)
  tag=$(pin_get "$file" "${prefix}_TAG")
  need "${tool}'s tag" "$tag" || return 1
  arches=$(pin_arches "$file" "$tool" "${prefix}_ASSET")
  need "${tool}'s asset names" "$arches" || return 1
  echo "current $tag"
  tags=$(aged_release_tags "$repo") || return 1
  for cand in $tags; do
    release=$(gh api "repos/$repo/releases/tags/$cand") \
      || {
        fail_lookup "can't read $repo's release $cand"
        return 1
      }
    names=''
    for arch in $arches; do
      template=$(pin_get "$file" "${prefix}_ASSET_$arch")
      name=$(expand_asset "$template" "$cand")
      valid name "$name" \
        || {
          fail_lookup "$cand expands $template to a bad name"
          return 1
        }
      url=''
      read -r updated digest url < <(jq -r --arg n "$name" '.assets[]
        | select(.name == $n)
        | "\(.updated_at) \(.digest // "-") \(.browser_download_url)"' \
        <<<"$release")
      [ -n "$url" ] || {
        fail_lookup "$repo's release $cand has no asset $name; update the" \
          "template"
        return 1
      }
      when=$(epoch "$updated") \
        || {
          fail_lookup "$name in $cand has an unreadable date"
          return 1
        }
      # An asset replaced inside the cooldown holds the release back.
      [ "$when" -le "$CUTOFF" ] || continue 2
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
          || {
            fail_lookup "can't download $cand's $arch asset"
            return 1
          }
        [ -z "$digest" ] || [ "$digest" = "$sum" ] || {
          fail_lookup "$cand's $arch asset doesn't match GitHub's digest"
          return 1
        }
      fi
      if [ "$sum" != unhashed ]; then
        valid sha256 "$sum" \
          || {
            fail_lookup "$cand's $arch digest is malformed"
            return 1
          }
      fi
      echo "set ${prefix}_SHA256_$arch $sum"
    done
    return 0
  done
}

lookup_tag_commit() { # file tool
  local file=$1 tool=$2 repo prefix tag tags commit head cand sha status rc
  repo=$(pin_attr "$file" "$tool" repo) \
    || {
      fail_lookup "its header has no repo="
      return 1
    }
  prefix=$(pin_prefix "$file" "$tool" _TAG)
  tag=$(pin_get "$file" "${prefix}_TAG")
  commit=$(pin_get "$file" "${prefix}_COMMIT")
  need "${tool}'s tag" "$tag" || return 1
  need "${tool}'s commit" "$commit" || return 1
  echo "current $tag (${commit:0:12})"
  head=$(aged_branch_head "$repo") || return 1
  tags=$(aged_release_tags "$repo") || return 1
  for cand in $tags; do
    version_gt "$cand" "$tag" || return 0
    { sha=$(tag_commit "$repo" "$cand") && valid commit "$sha"; } \
      || {
        fail_lookup "can't resolve $repo's tag $cand"
        return 1
      }
    # A tag on a commit not yet in an aged push waits for one.
    rc=0
    status=$(compare_status "$repo" "$sha" "$head") || rc=$?
    [ "$rc" != 2 ] || return 1
    case $status in identical | ahead) ;; *) continue ;; esac
    rc=0
    status=$(compare_status "$repo" "$commit" "$sha") || rc=$?
    [ "$rc" != 1 ] || fail_lookup "$repo doesn't have the pinned commit"
    [ "$rc" = 0 ] || return 1
    # identical: the newer tag is on the pinned commit.
    case $status in
      ahead | identical) ;;
      *)
        fail_lookup "$repo's tag $cand isn't ahead of the pinned commit" \
          "($status)"
        return 1
        ;;
    esac
    echo "candidate $cand (${sha:0:12})"
    echo "key $tool@$cand"
    echo "set ${prefix}_TAG $cand"
    echo "set ${prefix}_COMMIT $sha"
    return 0
  done
}

lookup_branch_commit() { # file tool
  local file=$1 tool=$2 repo prefix commit head status rc
  repo=$(pin_attr "$file" "$tool" repo) \
    || {
      fail_lookup "its header has no repo="
      return 1
    }
  prefix=$(pin_prefix "$file" "$tool" _COMMIT)
  commit=$(pin_get "$file" "${prefix}_COMMIT")
  need "${tool}'s commit" "$commit" || return 1
  echo "current ${commit:0:12}"
  head=$(aged_branch_head "$repo") || return 1
  [ "$head" != "$commit" ] || return 0
  rc=0
  status=$(compare_status "$repo" "$commit" "$head") || rc=$?
  [ "$rc" != 1 ] || fail_lookup "$repo doesn't have the pinned commit"
  [ "$rc" = 0 ] || return 1
  case $status in
    ahead)
      echo "candidate ${head:0:12}"
      echo "key $tool@$head"
      echo "set ${prefix}_COMMIT $head"
      ;;
    behind) ;; # pinned past the aged head
    *)
      fail_lookup "the pinned commit isn't on $repo's default branch any" \
        "more ($status)"
      ;;
  esac
}

lookup_hf_model() { # file tool
  local file=$1 tool=$2 model prefix revision api info sha modified when
  local pinned_when tree key name entry sum
  model=$(pin_attr "$file" "$tool" model) \
    || {
      fail_lookup "its header has no model="
      return 1
    }
  prefix=$(pin_prefix "$file" "$tool" _REVISION)
  revision=$(pin_get "$file" "${prefix}_REVISION")
  need "${tool}'s revision" "$revision" || return 1
  need "${tool}'s files" "$(pin_arches "$file" "$tool" "${prefix}_FILE")" \
    || return 1
  echo "current ${revision:0:12}"
  api=https://huggingface.co/api/models/$model
  {
    info=$(fetch "$api") && sha=$(jq -r .sha <<<"$info") \
      && modified=$(jq -r .lastModified <<<"$info") && valid commit "$sha" \
      && when=$(epoch "$modified")
  } || {
    fail_lookup "can't read $model's head"
    return 1
  }
  # Hugging Face dates a revision only by its commit, which the pusher sets;
  # accepted, since the model is data files and a bump still needs your
  # merge and ghcr approval.
  if [ "$sha" = "$revision" ] || [ "$when" -gt "$CUTOFF" ]; then
    return 0
  fi
  {
    modified=$(fetch "$api/revision/$revision" | jq -r .lastModified) \
      && pinned_when=$(epoch "$modified")
  } || {
    fail_lookup "can't read $model's pinned revision"
    return 1
  }
  [ "$when" -gt "$pinned_when" ] || return 0
  tree=$(fetch "$api/tree/$sha") \
    || {
      fail_lookup "can't list $model's files at $sha"
      return 1
    }
  echo "candidate ${sha:0:12}"
  echo "key $tool@$sha"
  echo "set ${prefix}_REVISION $sha"
  for key in $(pin_arches "$file" "$tool" "${prefix}_FILE"); do
    name=$(pin_get "$file" "${prefix}_FILE_$key")
    entry=$(jq -r --arg p "$name" \
      '.[] | select(.path == $p) | .lfs.oid // "git"' <<<"$tree") \
      || {
        fail_lookup "$model's file list isn't JSON"
        return 1
      }
    [ -n "$entry" ] || {
      fail_lookup "$model has no $name at $sha"
      return 1
    }
    if [ "$entry" != git ]; then
      sum=$entry
    elif [ "${DRY_RUN:-}" = 1 ]; then
      sum=unhashed
    else
      sum=$(sha256_of_url "https://huggingface.co/$model/resolve/$sha/$name") \
        || {
          fail_lookup "can't download $model's $name"
          return 1
        }
    fi
    if [ "$sum" != unhashed ]; then
      valid sha256 "$sum" \
        || {
          fail_lookup "$model's $name digest is malformed"
          return 1
        }
    fi
    echo "set ${prefix}_SHA256_$key $sum"
  done
}

# Node's and Go's names for the pinned arches.
node_arch() { case $1 in X86_64) echo x64 ;; AARCH64) echo arm64 ;; esac }
go_arch() { case $1 in X86_64) echo amd64 ;; AARCH64) echo arm64 ;; esac }

# Node's active release keys: nodejs/release-keys' gpg-only-active-keys
# keyring at this commit, with its sha256 (docs/releasing.md).
NODE_KEYS_COMMIT=481637f813e912c4aa3622d7964ab426c97b8e8d
NODE_KEYS_SUM=140f2ad5260fd62773b6243ce8e1d3009645d558f121b8262c55e383dc285932

# Prints Node's SHASUMS256.txt for a version once its signature verifies
# against the pinned release keys. A subshell, for the trap.
node_sums() ( # version
  tmp=$(mktemp -d) || exit 1
  trap 'rm -rf "$tmp"' EXIT
  keys=https://raw.githubusercontent.com/nodejs/release-keys
  keys+=/$NODE_KEYS_COMMIT/gpg-only-active-keys/pubring.kbx
  sums=https://nodejs.org/dist/$1/SHASUMS256.txt
  {
    fetch -o "$tmp/keys.kbx" "$keys" \
      && [ "$(sha256sum <"$tmp/keys.kbx" | cut -d' ' -f1)" = "$NODE_KEYS_SUM" ]
  } || {
    fail_lookup "can't read Node's pinned release keys"
    exit 1
  }
  { fetch -o "$tmp/sums" "$sums" && fetch -o "$tmp/sums.sig" "$sums.sig"; } \
    || {
      fail_lookup "can't read Node $1's SHASUMS256.txt or its signature"
      exit 1
    }
  gpg_keys() { GNUPGHOME=$tmp gpg --batch --no-default-keyring \
    --keyring "$tmp/keys.kbx" --trust-model always "$@" 2>/dev/null; }
  status=$(gpg_keys --status-fd 1 --verify "$tmp/sums.sig" "$tmp/sums") \
    || true
  case $status in
    *'[GNUPG:] VALIDSIG '*) why='' ;;
    *'[GNUPG:] BADSIG '*) why="doesn't match its signature" ;;
    *'[GNUPG:] NO_PUBKEY '*) why="isn't signed by a pinned release key" ;;
    *) why="has a signature gpg couldn't check" ;;
  esac
  # gpg passes a good signature from a revoked key, and calls one from a
  # revoked, expired key merely expired: ask for the key's own validity.
  if [ -z "$why" ]; then
    signer=$(awk '$2 == "VALIDSIG" { print $NF }' <<<"$status")
    validity=$(gpg_keys --with-colons --list-keys "$signer" \
      | awk -F: '$1 == "pub" { print $2 }')
    case $validity in
      r) why='is signed by a revoked release key' ;;
      '') why="has a signature gpg couldn't check" ;;
    esac
  fi
  if [ -n "$why" ]; then
    fail_lookup "Node $1's SHASUMS256.txt $why"
    exit 1
  fi
  cat "$tmp/sums"
)

lookup_node() { # file tool
  local file=$1 tool=$2 prefix version index listing cand sums arch name sum
  prefix=$(pin_prefix "$file" "$tool" _VERSION)
  version=$(pin_get "$file" "${prefix}_VERSION")
  need "node's version" "$version" || return 1
  need "node's digests" "$(pin_arches "$file" "$tool" "${prefix}_SHA256")" \
    || return 1
  echo "current $version"
  {
    index=$(fetch https://nodejs.org/dist/index.json) \
      && listing=$(jq -r '.[] | select(.lts != false)
        | "\(.date) \(.version)"' <<<"$index") && [ -n "$listing" ]
  } || {
    fail_lookup "can't read nodejs.org's LTS releases"
    return 1
  }
  # nodejs.org dates a release only by its files' timestamps; accepted,
  # since a bump still needs your merge and ghcr approval.
  {
    cand=$(while read -r at v; do
      when=$(epoch "$at") || exit 1
      if [ "$when" -le "$CUTOFF" ] && numeric_version "$v"; then echo "$v"; fi
    done <<<"$listing" | sort -rV | sed -n 1p) && [ -n "$cand" ]
  } || {
    fail_lookup "no readable LTS release past the cooldown"
    return 1
  }
  version_gt "$cand" "$version" || return 0
  sums=$(node_sums "$cand") || return 1
  echo "candidate $cand"
  echo "key $tool@$cand"
  echo "set ${prefix}_VERSION $cand"
  for arch in $(pin_arches "$file" "$tool" "${prefix}_SHA256"); do
    name=node-$cand-linux-$(node_arch "$arch").tar.gz
    sum=$(awk -v n="$name" '$2 == n { print $1 }' <<<"$sums")
    valid sha256 "$sum" \
      || {
        fail_lookup "SHASUMS256.txt has no sha256 for $name"
        return 1
      }
    echo "set ${prefix}_SHA256_$arch $sum"
  done
}

lookup_go() { # file tool
  local file=$1 tool=$2 prefix version json versions cand arch name sum
  local modified when sets
  prefix=$(pin_prefix "$file" "$tool" _VERSION)
  version=$(pin_get "$file" "${prefix}_VERSION")
  need "go's version" "$version" || return 1
  need "go's digests" "$(pin_arches "$file" "$tool" "${prefix}_SHA256")" \
    || return 1
  echo "current $version"
  {
    json=$(fetch 'https://go.dev/dl/?mode=json&include=all') \
      && versions=$(jq -r '.[] | select(.stable) | .version
        | ltrimstr("go")' <<<"$json") && [ -n "$versions" ]
  } || {
    fail_lookup "can't read go.dev's stable releases"
    return 1
  }
  while read -r cand; do
    numeric_version "$cand" || continue
    version_gt "$cand" "$version" || return 0
    sets=''
    for arch in $(pin_arches "$file" "$tool" "${prefix}_SHA256"); do
      name=go$cand.linux-$(go_arch "$arch").tar.gz
      sum=$(jq -r --arg n "$name" \
        '.[].files[] | select(.filename == $n) | .sha256' <<<"$json")
      valid sha256 "$sum" \
        || {
          fail_lookup "go.dev lists no sha256 for $name"
          return 1
        }
      # go.dev dates a release only by its download's Last-Modified.
      {
        modified=$(fetch -I "https://dl.google.com/go/$name" \
          | sed -n 's/^[Ll]ast-[Mm]odified: *//p' | tr -d '\r' | tail -n 1) \
          && [ -n "$modified" ] && when=$(epoch "$modified")
      } || {
        fail_lookup "can't read $name's Last-Modified"
        return 1
      }
      [ "$when" -le "$CUTOFF" ] || continue 2
      sets+="set ${prefix}_SHA256_$arch $sum"$'\n'
    done
    echo "candidate $cand"
    echo "key $tool@$cand"
    echo "set ${prefix}_VERSION $cand"
    printf '%s' "$sets"
    return 0
  done < <(sort -rV <<<"$versions")
}

# Prints "name versions" for each requirement in a requirements file, the
# versions joined by "|" (which no version holds) when platform markers pin a
# name more than once.
lock_pins() { # file
  sed -n 's/^\([A-Za-z0-9._-]*\)==\([^ ;\\]*\).*/\1 \2/p' "$1" \
    | awk '{ name = tolower($1); gsub(/_/, "-", name); print name, $2 }' \
    | LC_ALL=C sort -u | awk '
      $1 == last { line = line "|" $2; next }
      NR > 1 { print line }
      { last = $1; line = $1 " " $2 }
      END { if (NR) print line }'
}

comma_list() { # items...
  local IFS=,
  local list="$*"
  echo "${list//,/, }"
}

max_version() { # versions joined by |
  local v best=''
  local -a vs
  IFS='|' read -ra vs <<<"$1"
  for v in "${vs[@]}"; do
    if [ -z "$best" ] || version_gt "$v" "$best"; then best=$v; fi
  done
  echo "$best"
}

# Regenerates the lock from its input with the cutoff, and offers it only when
# a requirement moved up and none moved down, so a fix that landed inside the
# cooldown is never rolled back. Run from the repository root.
lookup_uv_lock() { # file tool
  local file=$1 tool=$2 dir lock input new before name old version up=0
  local down='' old_max new_max
  local -a changes=() from=() to=()
  dir=$(dirname "$file")
  {
    lock=$dir/$(pin_attr "$file" "$tool" lock) \
      && input=$dir/$(pin_attr "$file" "$tool" input) \
      && [ -f "$lock" ] && [ -f "$input" ]
  } || {
    fail_lookup "its header needs an existing lock= and input="
    return 1
  }
  echo "current $tool==$(lock_pins "$lock" | awk -v t="$tool" '$1 == t {
    print $2 }')"
  new=$(mktemp)
  before=$(date -u -d "@$CUTOFF" +%Y-%m-%dT%H:%M:%SZ)
  uv pip compile "$input" --universal --python-version 3.12 \
    --generate-hashes --no-build --upgrade --no-header --quiet \
    --exclude-newer "$before" -o "$new" \
    || {
      fail_lookup "uv pip compile failed"
      rm -f "$new"
      return 1
    }
  while read -r name old version; do
    [ "$old" != "$version" ] || continue
    if [ "$old" = - ]; then
      changes+=("$name: added $version")
    elif [ "$version" = - ]; then
      changes+=("$name: removed")
    else
      old_max=$(max_version "$old")
      new_max=$(max_version "$version")
      if version_gt "$new_max" "$old_max"; then
        up=1
      elif version_gt "$old_max" "$new_max"; then
        down+=" $name"
      fi
      # Shown with "/" between a name's versions: "|" would split a table cell.
      changes+=("$name: ${old//|/\/} → ${version//|/\/}")
      from+=("$name==${old//|/\/}")
      to+=("$name==${version//|/\/}")
    fi
  done < <(LC_ALL=C join -a1 -a2 -e - -o 0,1.2,2.2 <(lock_pins "$lock") \
    <(lock_pins "$new"))
  if [ -n "$down" ]; then
    echo "note keeps the committed lock: it would move${down} down"
  fi
  if [ "$up" = 0 ] || [ -n "$down" ]; then
    rm -f "$new"
    return 0
  fi
  echo "from $(comma_list "${from[@]}")"
  echo "candidate $(comma_list "${to[@]}")"
  echo "key $tool@lock-$(lock_pins "$new" | sha256sum | cut -c1-12)"
  echo "lock $lock $new"
  printf 'change %s\n' "${changes[@]}"
}
