# shellcheck shell=bash source-path=SCRIPTDIR
# Sourced by shim.sh and activation-steps.sh before they run Liza. Liza reads
# its provider catalog, which decides what it runs for each provider and where
# init writes, from upstream main unless LIZA_PROVIDER_CATALOG_URL names
# another: this names the catalog at the pinned release's commit, unless you
# named one.
# shellcheck source=pins.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/pins.sh"
if [ -z "${LIZA_PROVIDER_CATALOG_URL:-}" ]; then
  LIZA_PROVIDER_CATALOG_URL=https://raw.githubusercontent.com/liza-mas/liza
  LIZA_PROVIDER_CATALOG_URL+=/$LIZA_COMMIT/provider-catalog.yaml
fi
export LIZA_PROVIDER_CATALOG_URL
