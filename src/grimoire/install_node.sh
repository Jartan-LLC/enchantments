#!/bin/bash
# install.sh's Node step, as root: install the pinned Node's binary alone into
# the bin of the directory given. The hooks need only node, and npm and npx
# stay off PATH.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=fetch_verified.sh
. "$here/fetch_verified.sh"
# shellcheck source=pins.sh
. "$here/pins.sh"
dest=$1

case "$(uname -m)" in
  x86_64 | amd64) arch=x64 sha256=$NODE_SHA256_X86_64 ;;
  aarch64 | arm64) arch=arm64 sha256=$NODE_SHA256_AARCH64 ;;
  *)
    echo "unsupported architecture $(uname -m)" >&2
    exit 1
    ;;
esac
tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
# .tar.gz, not .tar.xz, so the image needs no xz.
name=node-$NODE_VERSION-linux-$arch
if ! { fetch_verified "https://nodejs.org/dist/$NODE_VERSION/$name.tar.gz" \
  "$sha256" "$tmp/node.tar.gz" \
  && mkdir -p "$dest/bin" \
  && tar -xzf "$tmp/node.tar.gz" -C "$dest/bin" --strip-components=2 \
    --no-same-owner "$name/bin/node" \
  && "$dest/bin/node" --version >/dev/null; }; then
  # A node that can't run would pass postStart's check.
  rm -rf "${dest:?}/bin"
  exit 1
fi
