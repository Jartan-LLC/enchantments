#!/bin/bash
# shellcheck source-path=SCRIPTDIR
# Fails unless every Feature's :1 resolves without credentials, as consumers
# pull it.
set -euo pipefail
# shellcheck source=feature_ids.sh
. "$(dirname "$0")/feature_ids.sh"
private=()
for id in $(feature_ids); do
  if ! env -u GITHUB_TOKEN DOCKER_CONFIG="$(mktemp -d)" \
    node_modules/.bin/devcontainer features info manifest \
    "ghcr.io/jartan-llc/enchantments/$id:1" >/dev/null; then
    private+=("$id")
  fi
done
if [ "${#private[@]}" -gt 0 ]; then
  echo "::error::not publicly readable at :1: ${private[*]}"
  exit 1
fi
