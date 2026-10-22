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
  local tags
  tags=$(ghcr_tags "$1") || return 2
  jq -e --arg v "$2" '.publishedTags | index($v)' <<<"$tags" >/dev/null \
    || return 1
}

# Prints the highest X.Y.Z among the Feature's published tags, nothing when
# none is; returns 2 when the lookup fails.
ghcr_latest() { # id
  local tags
  tags=$(ghcr_tags "$1") || return 2
  jq -r '.publishedTags[] | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))' \
    <<<"$tags" | sort -V | tail -n 1
}

# Prints a failed lookup's stderr, saved in a file, on one line, without the
# CLI's timestamps.
ghcr_cause() { # file
  sed 's/^\[[^]]*\] //' "$1" | paste -sd ' ' -
}
