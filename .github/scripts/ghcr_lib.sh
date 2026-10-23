# shellcheck shell=bash
# Looks Features up on GHCR, through the devcontainer CLI in node_modules.
# Needs GITHUB_TOKEN to see private packages. Sourced.

# Prints the tags published under the Feature's :1, as JSON; fails when the
# lookup does, as it does for a Feature never published. The bare ref would
# mean latest, and a deleted latest would hide every version.
ghcr_tags() { # id
  node_modules/.bin/devcontainer features info tags \
    "ghcr.io/jartan-llc/enchantments/$1:1" --output-format json
}

# Succeeds when the Feature's :1 lists the version among its published tags;
# returns 1 when it doesn't, and 2 when the lookup fails.
ghcr_has() { # id version
  local tags rc=0
  tags=$(ghcr_tags "$1") || return 2
  jq -e --arg v "$2" '.publishedTags | index($v)' <<<"$tags" >/dev/null \
    || rc=$?
  # jq -e exits 1 for a null result, higher for output it can't parse.
  case $rc in 0 | 1) return "$rc" ;; *) return 2 ;; esac
}

# Prints the highest X.Y.Z among the Feature's published tags, nothing when
# none is; returns 2 when the lookup fails.
ghcr_latest() { # id
  local tags versions
  tags=$(ghcr_tags "$1") || return 2
  versions=$(jq -r '.publishedTags[]
    | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))' <<<"$tags") || return 2
  [ -z "$versions" ] || sort -V <<<"$versions" | tail -n 1
}

# Prints a failed lookup's stderr, saved in a file, on one line, without the
# CLI's timestamps.
ghcr_cause() { # file
  sed 's/^\[[^]]*\] //' "$1" | paste -sd ' ' -
}
