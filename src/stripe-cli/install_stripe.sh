#!/bin/bash
# install.sh's stripe step, as root: install the pinned release binary to the
# path given.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=fetch_verified.sh
. "$here/fetch_verified.sh"
# shellcheck source=install_asset.sh
. "$here/install_asset.sh"
# shellcheck source=pins.sh
. "$here/pins.sh"

case "$(uname -m)" in
  x86_64 | amd64) asset=$STRIPE_ASSET_X86_64 sha256=$STRIPE_SHA256_X86_64 ;;
  aarch64 | arm64) asset=$STRIPE_ASSET_AARCH64 sha256=$STRIPE_SHA256_AARCH64 ;;
  *)
    echo "unsupported architecture $(uname -m)" >&2
    exit 1
    ;;
esac
asset=${asset//\{tag\}/$STRIPE_TAG}
asset=${asset//\{version\}/${STRIPE_TAG#v}}
install_asset \
  "https://github.com/stripe/stripe-cli/releases/download/$STRIPE_TAG/$asset" \
  "$sha256" stripe "$1"
