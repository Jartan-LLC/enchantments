#!/bin/bash
# onCreateCommand, as the remote user: link ~/.liza to this project's volume,
# install the pinned Liza binary and ripgrep into it, and put liza,
# liza-activate, liza-deactivate and rg in ~/.local/bin. Activation waits for
# updateContentCommand, by when every Feature's onCreate has run.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
# shellcheck source=fix_volume_owner.sh
. "$here/fix_volume_owner.sh"
# shellcheck source=link_home.sh
. "$here/link_home.sh"
# shellcheck source=fetch_verified.sh
. "$here/fetch_verified.sh"
# shellcheck source=pins.sh
. "$here/pins.sh"
id=liza
mount=/mnt/enchantments/liza
retry="retry: bash $here/onCreate.sh"

case "$(uname -m)" in
  x86_64 | amd64) arch=X86_64 ;;
  aarch64 | arm64) arch=AARCH64 ;;
  *)
    record_failure "$id" "unsupported architecture $(uname -m); nothing" \
      "installed"
    exit 0
    ;;
esac

fix_volume_owner "$mount" \
  || record_failure "$id" "can't take ownership of $mount without" \
    "passwordless sudo; run: sudo chown -R $(id -un) $mount"
linked=true
link_home "$HOME/.liza" "$mount" || {
  linked=false
  record_failure "$id" "$HOME/.liza is in the way of the liza volume; move" \
    "it aside, then run: bash $here/onCreate.sh"
}

# Prints the pinned asset name for this architecture, its template expanded.
asset_name() { # pin-prefix
  local tag=${1}_TAG template=${1}_ASSET_$arch
  tag=${!tag}
  template=${!template//\{tag\}/$tag}
  echo "${template//\{version\}/${tag#v}}"
}

# Downloads a pinned release archive, checks its digest, and installs one
# member of it as an executable.
install_member() { # url sha256 member destination
  local tmp rc
  tmp=$(mktemp -d) || return 1
  fetch_verified "$1" "$2" "$tmp/asset.tar.gz" \
    && tar -xzf "$tmp/asset.tar.gz" -C "$tmp" --no-same-owner "$3" \
    && mkdir -p "$(dirname "$4")" \
    && install -m 755 "$tmp/$3" "$4"
  rc=$?
  rm -rf "$tmp"
  return "$rc"
}

# Through the mount, not ~/.liza, so a failed link never redirects them.
liza=$mount/libexec/liza
if ! "$liza" version 2>/dev/null | grep -qx "liza version ${LIZA_TAG#v}"; then
  sha256=LIZA_SHA256_$arch
  asset=$(asset_name LIZA)
  install_member \
    "https://github.com/liza-mas/liza/releases/download/$LIZA_TAG/$asset" \
    "${!sha256}" liza "$liza" \
    || record_failure "$id" "install of Liza $LIZA_TAG failed (download or" \
      "digest mismatch); $retry"
fi
rg=$mount/bin/rg
if ! "$rg" --version 2>/dev/null | grep -q "^ripgrep $RG_TAG "; then
  sha256=RG_SHA256_$arch
  asset=$(asset_name RG)
  install_member \
    "https://github.com/BurntSushi/ripgrep/releases/download/$RG_TAG/$asset" \
    "${!sha256}" "${asset%.tar.gz}/rg" "$rg" \
    || record_failure "$id" "install of ripgrep $RG_TAG failed (download" \
      "or digest mismatch); $retry"
fi

# The wrappers and the rg link point through ~/.liza.
$linked || exit 0
# Wrappers, not links: the scripts find their helpers from their own path.
write_wrapper() { # name script
  printf '#!/bin/sh\nexec bash %s "$@"\n' "$here/$2" >"$HOME/.local/bin/$1" \
    && chmod 755 "$HOME/.local/bin/$1"
}
if ! { mkdir -p "$HOME/.local/bin" \
  && write_wrapper liza shim.sh \
  && write_wrapper liza-activate activate.sh \
  && write_wrapper liza-deactivate deactivate.sh \
  && ln -sfn "$HOME/.liza/bin/rg" "$HOME/.local/bin/rg"; }; then
  record_failure "$id" "couldn't write liza, liza-activate, liza-deactivate" \
    "and rg into $HOME/.local/bin; $retry"
fi
