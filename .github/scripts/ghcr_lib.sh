# shellcheck shell=bash
# Looks Features up on GHCR, through the devcontainer CLI in node_modules.
# Needs GITHUB_TOKEN to see private packages. Sourced.

# Succeeds when the Feature's :1 lists the version among its published tags;
# returns 1 when it doesn't, and 2 when the lookup fails. The bare ref would
# mean latest, and a deleted latest would hide every version.
ghcr_has() { # id version
  local tags
  tags=$(node_modules/.bin/devcontainer features info tags \
    "ghcr.io/jartan-llc/enchantments/$1:1" --output-format json) || return 2
  jq -e --arg v "$2" '.publishedTags | index($v)' <<<"$tags" >/dev/null \
    || return 1
}
