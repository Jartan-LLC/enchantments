#!/bin/bash
# onCreateCommand, as the remote user: install the pinned binary into
# ~/.local/bin. Registration waits for updateContentCommand, by when
# claude-code's onCreate has run.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
# shellcheck source=fetch_verified.sh
. "$here/fetch_verified.sh"
# shellcheck source=pins.sh
. "$here/pins.sh"
id=codebase-memory-mcp
bin=$HOME/.local/bin/codebase-memory-mcp
releases=https://github.com/DeusData/codebase-memory-mcp/releases/download

case "$(uname -m)" in
  x86_64 | amd64) asset=$CBM_ASSET_X86_64 sha256=$CBM_SHA256_X86_64 ;;
  aarch64 | arm64) asset=$CBM_ASSET_AARCH64 sha256=$CBM_SHA256_AARCH64 ;;
  *)
    record_failure "$id" "unsupported architecture $(uname -m); nothing" \
      "installed"
    exit 0
    ;;
esac
"$bin" --version 2>/dev/null | grep -qwF "${CBM_TAG#v}" && exit 0

# The release's own install subcommand places the binary. --skip-config stops
# it writing a skill, agents and hooks into the shared claude-data. Upstream's
# install.sh is skipped: it re-downloads checksums.txt after any check of ours.
# The install subcommand only stages a file the current user owns, and root's
# tar would keep the archive's owner.
tmp=$(mktemp -d) || {
  record_failure "$id" "no temporary directory; nothing installed"
  exit 0
}
fetch_verified "$releases/$CBM_TAG/$asset" "$sha256" "$tmp/release.tar.gz" \
  && tar -xzf "$tmp/release.tar.gz" -C "$tmp" --no-same-owner \
    codebase-memory-mcp \
  && "$tmp/codebase-memory-mcp" install -y --force --dir="$HOME/.local/bin" \
    --skip-config </dev/null
rm -rf "$tmp"
if ! "$bin" --version 2>/dev/null | grep -qwF "${CBM_TAG#v}"; then
  record_failure "$id" "install of $CBM_TAG failed (download, digest mismatch" \
    "or installer error); retry: bash $here/onCreate.sh"
fi
