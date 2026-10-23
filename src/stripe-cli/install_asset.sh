# shellcheck shell=bash
# make vendor copies this into each Feature that uses it: edit
# lib/install_asset.sh, not a copy.

# Fetches a release asset, checks its digest, and installs one executable from
# it: a member of a .tar.gz or .zip, or the asset itself. Members go through
# stdout, so an archive's owners never reach the disk, as root's tar would
# otherwise keep them. Needs fetch_verified.
install_asset() { # url sha256 member destination
  local tmp rc
  tmp=$(mktemp -d) || return 1
  fetch_verified "$1" "$2" "$tmp/asset" && case "$1" in
    *.zip) unzip -p "$tmp/asset" "$3" >"$tmp/binary" ;;
    *.tar.gz) tar -xzf "$tmp/asset" -O "$3" >"$tmp/binary" ;;
    *) mv "$tmp/asset" "$tmp/binary" ;;
  esac && mkdir -p "$(dirname "$4")" && install -m 755 "$tmp/binary" "$4"
  rc=$?
  rm -rf "$tmp"
  return "$rc"
}
