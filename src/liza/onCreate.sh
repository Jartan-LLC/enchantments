#!/bin/bash
# onCreateCommand, as the remote user: link ~/.liza to this project's volume,
# install the pinned Liza binary, ripgrep and, where you have none,
# pre-commit into it, and put liza, liza-activate, liza-deactivate and rg in
# ~/.local/bin. Activation waits for updateContentCommand, by when every
# Feature's onCreate has run.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
# shellcheck source=volume_owner.sh
. "$here/volume_owner.sh"
# shellcheck source=link_home.sh
. "$here/link_home.sh"
# shellcheck source=fetch_verified.sh
. "$here/fetch_verified.sh"
# shellcheck source=install_asset.sh
. "$here/install_asset.sh"
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

problem=$(fix_volume_owner "$mount" "Liza's install may fail") \
  || record_failure "$id" "$problem"
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

# Through the mount, not ~/.liza, so a failed link never redirects them.
liza=$mount/libexec/liza
if ! "$liza" version 2>/dev/null | grep -qx "liza version ${LIZA_TAG#v}"; then
  sha256=LIZA_SHA256_$arch
  asset=$(asset_name LIZA)
  install_asset \
    "https://github.com/liza-mas/liza/releases/download/$LIZA_TAG/$asset" \
    "${!sha256}" liza "$liza" \
    || record_failure "$id" "install of Liza $LIZA_TAG failed (download or" \
      "digest mismatch); $retry"
fi
rg=$mount/bin/rg
if ! "$rg" --version 2>/dev/null | grep -q "^ripgrep $RG_TAG "; then
  sha256=RG_SHA256_$arch
  asset=$(asset_name RG)
  install_asset \
    "https://github.com/BurntSushi/ripgrep/releases/download/$RG_TAG/$asset" \
    "${!sha256}" "${asset%.tar.gz}/rg" "$rg" \
    || record_failure "$id" "install of ripgrep $RG_TAG failed (download" \
      "or digest mismatch); $retry"
fi

# Liza's multi-agent init needs pre-commit: installed only when none of yours
# comes first on PATH, in a directory of its own, apart from liza-toolchain's
# uv and Python. Its bin goes last on PATH, so one you install later wins.
pre_commit=$mount/lib/pre-commit
lock_sum=$(sha256sum <"$here/$PRE_COMMIT_REQUIREMENTS" | cut -d' ' -f1)
pre_commit_pins="$PRE_COMMIT_UV_TAG $PRE_COMMIT_PYTHON_VERSION $lock_sum $arch"

# Builds pre-commit's venv afresh, with the pinned Python, which uv checks
# against the sha256 it carries, and a uv fetched for the build only. The old
# install is set aside and put back if the build fails: a venv records its
# own path, so the new one can't be built elsewhere and moved into place.
install_pre_commit() {
  local tmp rc asset sha256=PRE_COMMIT_UV_SHA256_$arch
  local tag=$PRE_COMMIT_UV_TAG old=$pre_commit.old
  asset=$(asset_name PRE_COMMIT_UV)
  tmp=$(mktemp -d) || return 1
  # No uv.toml or pyproject.toml of the workspace may steer this install.
  local -x UV_NO_CONFIG=1 UV_CACHE_DIR=$tmp/cache
  rm -rf "$old"
  install_asset \
    "https://github.com/astral-sh/uv/releases/download/$tag/$asset" \
    "${!sha256}" "${asset%.tar.gz}/uv" "$tmp/uv" \
    && { [ ! -e "$pre_commit" ] || mv "$pre_commit" "$old"; } \
    && UV_PYTHON_INSTALL_DIR=$pre_commit/python "$tmp/uv" venv -q \
      --managed-python --python "$PRE_COMMIT_PYTHON_VERSION" \
      "$pre_commit/venv" \
    && "$tmp/uv" pip install -q --python "$pre_commit/venv/bin/python" \
      --require-hashes -r "$here/$PRE_COMMIT_REQUIREMENTS" \
    && mkdir "$pre_commit/bin" \
    && ln -s ../venv/bin/pre-commit "$pre_commit/bin/pre-commit" \
    && echo "$pre_commit_pins" >"$pre_commit/pins"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    rm -rf "$old"
  elif [ -e "$old" ]; then
    rm -rf "$pre_commit" && mv "$old" "$pre_commit"
  fi
  rm -rf "$tmp"
  return "$rc"
}

# Succeeds when the installed pre-commit matches its pins and runs.
pre_commit_current() {
  [ "$(cat "$pre_commit/pins" 2>/dev/null)" = "$pre_commit_pins" ] \
    && "$pre_commit/bin/pre-commit" --version >/dev/null 2>&1
}

# On a rebuild, PATH finds the Feature's own link: that one is still
# reinstalled when its pins change.
yours=$(command -v pre-commit)
if { [ -z "$yours" ] || [ "$yours" -ef "$pre_commit/bin/pre-commit" ]; } \
  && ! pre_commit_current; then
  install_pre_commit \
    || record_failure "$id" "install of pre-commit failed (download, digest" \
      "mismatch or install error); $retry"
fi

# The wrappers and the rg link point through ~/.liza.
$linked || exit 0
# Wrappers, not links: the scripts find their helpers from their own path. A
# link at the wrapper's path is replaced, never written through.
write_wrapper() { # name script
  local path=$HOME/.local/bin/$1
  rm -f -- "$path" \
    && printf '#!/bin/sh\nexec bash %s "$@"\n' "$here/$2" >"$path" \
    && chmod 755 "$path"
}
# Only where no rg of your own is.
link_rg() {
  local path=$HOME/.local/bin/rg
  [ -e "$path" ] || [ -L "$path" ] || ln -s "$HOME/.liza/bin/rg" "$path"
}
if ! { mkdir -p "$HOME/.local/bin" \
  && write_wrapper liza shim.sh \
  && write_wrapper liza-activate activate.sh \
  && write_wrapper liza-deactivate deactivate.sh \
  && link_rg; }; then
  record_failure "$id" "couldn't write liza, liza-activate, liza-deactivate" \
    "and rg into $HOME/.local/bin; $retry"
fi
