#!/bin/bash
# onCreateCommand, as the remote user: install Liza's agent toolchain, every
# tool pinned, into the liza Feature's volume. It writes only through the
# mount, never through ~/.liza, which liza's onCreate links and may not have
# yet. Each tool records its pin in bin/.pins, so a re-run installs only what
# changed, and a failed tool is retried on the next create.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
# shellcheck source=fix_volume_owner.sh
. "$here/fix_volume_owner.sh"
# shellcheck source=fetch_verified.sh
. "$here/fetch_verified.sh"
# shellcheck source=pins.sh
. "$here/pins.sh"
id=liza-toolchain
mount=/mnt/enchantments/liza
bin=$mount/bin
lib=$mount/lib
pins=$bin/.pins
retry="retry: bash $here/onCreate.sh"

# The volume is liza's: without it, there's nowhere to install.
if [ ! -d /usr/local/share/enchantments/liza ]; then
  record_failure "$id" "liza-toolchain without liza: nothing installed"
  exit 0
fi
case "$(uname -m)" in
  x86_64 | amd64) arch=X86_64 goarch=amd64 node_arch=x64 ;;
  aarch64 | arm64) arch=AARCH64 goarch=arm64 node_arch=arm64 ;;
  *)
    record_failure "$id" "unsupported architecture $(uname -m); nothing" \
      "installed"
    exit 0
    ;;
esac
fix_volume_owner "$mount" \
  || record_failure "$id" "can't take ownership of $mount without" \
    "passwordless sudo; run: sudo chown -R $(id -un) $mount"
if ! mkdir -p "$bin" "$lib" "$pins"; then
  record_failure "$id" "can't write to $mount; nothing installed"
  exit 0
fi

# Prints this architecture's value of a per-arch pin.
pinned() { # name
  local name=${1}_$arch
  echo "${!name}"
}

# Runs an installer unless the tool's recorded pin already matches. A failure
# is recorded and leaves the pin unrecorded.
install_pinned() { # tool pin installer...
  local tool=$1 pin=$2
  [ "$(cat "$pins/$tool" 2>/dev/null)" = "$pin" ] && return 0
  echo "Installing $tool ($pin)..."
  if "${@:3}"; then
    echo "$pin" >"$pins/$tool"
  else
    record_failure "$id" "$tool install failed (download, digest mismatch" \
      "or build error); $retry"
    return 1
  fi
}

# Downloads a release asset, checks its digest, and installs one executable
# from it.
# shellcheck disable=SC2329 # run through install_pinned
release_binary() { # destination url sha256 member (empty for a bare binary)
  local tmp rc
  tmp=$(mktemp -d) || return 1
  fetch_verified "$2" "$3" "$tmp/asset" && case "$2" in
    *.zip) unzip -p "$tmp/asset" "$4" >"$tmp/binary" ;;
    *.tar.gz) tar -xzf "$tmp/asset" -O "$4" >"$tmp/binary" ;;
    *) mv "$tmp/asset" "$tmp/binary" ;;
  esac && mkdir -p "$(dirname "$1")" && install -m 755 "$tmp/binary" "$1"
  rc=$?
  rm -rf "$tmp"
  return "$rc"
}

# Installs a pinned release binary into bin.
release_tool() { # tool repo tag-var prefix member
  local tag=${!3}
  install_pinned "$1" "$tag" release_binary "$bin/$1" \
    "https://github.com/$2/releases/download/$tag/$(pinned "${4}_ASSET")" \
    "$(pinned "${4}_SHA256")" "$5"
}

if command -v unzip >/dev/null; then
  release_tool ast-grep ast-grep/ast-grep AST_GREP_TAG AST_GREP ast-grep
else
  record_failure "$id" "ast-grep ships as a zip, and this image has no" \
    "unzip; install it, then $retry"
fi
release_tool yq mikefarah/yq YQ_TAG YQ ""
release_tool rtk rtk-ai/rtk RTK_TAG RTK rtk
# rtk's only arm64 build is glibc-linked. Without its pin, each create retries.
if [ -e "$bin/rtk" ] && ! "$bin/rtk" --version >/dev/null 2>&1; then
  rm -f "$bin/rtk" "$pins/rtk"
  record_failure "$id" "rtk $RTK_TAG doesn't run here (its arm64 build" \
    "needs glibc 2.39 or later), so it's removed; ~/.liza/AGENT_TOOLS.md" \
    "still describes rtk, which this container lacks"
fi
# mdq publishes no arm64 Linux build, and nothing depends on it.
[ "$arch" = X86_64 ] && release_tool mdq yshavit/mdq MDQ_TAG MDQ mdq

# Built from source at a pinned commit, whose go.sum fixes the dependencies,
# with a pinned Go fetched only when one is stale and deleted afterwards.
go_tools=(
  "stacklit liza-mas/stacklit-cli $STACKLIT_COMMIT"
  "scip-search liza-mas/scip-search $SCIP_SEARCH_COMMIT"
  "functional-clusters liza-mas/functional-clusters $FUNCTIONAL_CLUSTERS_COMMIT"
  "mdtoc liza-mas/mdtoc $MDTOC_COMMIT"
  "bash-policy liza-mas/bash-policy $BASH_POLICY_COMMIT"
)
stale=()
for entry in "${go_tools[@]}"; do
  read -r tool repo commit <<<"$entry"
  [ "$(cat "$pins/$tool" 2>/dev/null)" = "$commit" ] || stale+=("$entry")
done

# shellcheck disable=SC2329 # run through install_pinned
go_build() { # tool repo commit
  local src
  src=$(mktemp -d -p "$gotmp") || return 1
  git -C "$src" init -q \
    && git -C "$src" fetch -q --depth 1 "https://github.com/$2" "$3" \
    && git -C "$src" checkout -q FETCH_HEAD \
    && (cd "$src" && CGO_ENABLED=0 GOTOOLCHAIN=local GOFLAGS=-mod=readonly \
      GOPATH="$gotmp/gopath" GOCACHE="$gotmp/cache" \
      GOMODCACHE="$gotmp/gopath/pkg/mod" \
      "$gotmp/go/bin/go" build -trimpath -o "$bin/$1" "./cmd/$1")
}

if [ "${#stale[@]}" -gt 0 ]; then
  go_url=https://dl.google.com/go/go$GO_VERSION.linux-$goarch.tar.gz
  if gotmp=$(mktemp -d) \
    && fetch_verified "$go_url" "$(pinned GO_SHA256)" "$gotmp/go.tar.gz" \
    && tar -xzf "$gotmp/go.tar.gz" -C "$gotmp" --no-same-owner; then
    for entry in "${stale[@]}"; do
      read -r tool repo commit <<<"$entry"
      install_pinned "$tool" "$commit" go_build "$tool" "$repo" "$commit"
    done
  else
    record_failure "$id" "Go $GO_VERSION download failed, so the Go tools" \
      "weren't built; $retry"
  fi
  # The module cache is read-only.
  if [ -n "${gotmp:-}" ]; then
    chmod -R u+w "$gotmp"
    rm -rf "$gotmp"
  fi
fi

# A private Node runs scip-python, scip-typescript and context7, through
# wrappers in bin, so no Node lands on PATH.
# shellcheck disable=SC2329 # run through install_pinned
node_tools() {
  local tmp rc tool target
  local name=node-$NODE_VERSION-linux-$node_arch.tar.gz
  tmp=$(mktemp -d) || return 1
  fetch_verified "https://nodejs.org/dist/$NODE_VERSION/$name" \
    "$(pinned NODE_SHA256)" "$tmp/node.tar.gz" \
    && rm -rf "$lib/node" && mkdir -p "$lib/node" "$lib/npm" \
    && tar -xzf "$tmp/node.tar.gz" -C "$lib/node" --strip-components=1 \
      --no-same-owner \
    && cp "$here/npm/package.json" "$here/npm/package-lock.json" "$lib/npm/" \
    && (cd "$lib/npm" && PATH="$lib/node/bin:$PATH" \
      npm_config_cache="$tmp/npm-cache" "$lib/node/bin/npm" ci \
      --ignore-scripts --no-audit --no-fund --no-update-notifier \
      --loglevel=error)
  rc=$?
  rm -rf "$tmp"
  [ "$rc" -eq 0 ] || return "$rc"
  for tool in scip-python scip-typescript context7-mcp; do
    target=$(readlink -f "$lib/npm/node_modules/.bin/$tool") \
      && printf '#!/bin/sh\nexec %s %s "$@"\n' "$lib/node/bin/node" \
        "$target" >"$bin/$tool" \
      && chmod 755 "$bin/$tool" \
      || return 1
  done
}
lock_sum=$(sha256sum <"$here/npm/package-lock.json" | cut -d' ' -f1)
install_pinned npm-tools "$NODE_VERSION $lock_sum" node_tools

# A private uv builds semble's venv, whose interpreter it downloads into the
# volume, so the venv never depends on the image's Python.
uv_asset=$(pinned UV_ASSET)
install_pinned uv "$UV_TAG" release_binary "$lib/uv/uv" \
  "https://github.com/astral-sh/uv/releases/download/$UV_TAG/$uv_asset" \
  "$(pinned UV_SHA256)" "${uv_asset%.tar.gz}/uv"

# The model is fetched at a pinned revision, so semble never downloads at
# runtime: env.append points SEMBLE_MODEL_NAME at it.
# shellcheck disable=SC2329 # run through install_pinned
semble_tool() {
  local tmp rc key file sha256
  local model=https://huggingface.co/minishlab/potion-code-16M-v2/resolve
  [ -x "$lib/uv/uv" ] || return 1
  tmp=$(mktemp -d) || return 1
  UV_CACHE_DIR=$tmp UV_PYTHON_INSTALL_DIR=$lib/python \
    "$lib/uv/uv" venv -q --clear --managed-python --python 3.12 \
    "$lib/semble" \
    && UV_CACHE_DIR=$tmp "$lib/uv/uv" pip install -q \
      --python "$lib/semble/bin/python" --require-hashes \
      -r "$here/$SEMBLE_REQUIREMENTS" \
    && ln -sfn "$lib/semble/bin/semble" "$bin/semble" \
    && mkdir -p "$lib/semble-model"
  rc=$?
  rm -rf "$tmp"
  [ "$rc" -eq 0 ] || return "$rc"
  for key in CONFIG MODEL MODULES TOKENIZER; do
    file=SEMBLE_MODEL_FILE_$key sha256=SEMBLE_MODEL_SHA256_$key
    fetch_verified "$model/$SEMBLE_MODEL_REVISION/${!file}" "${!sha256}" \
      "$lib/semble-model/${!file}" || return 1
  done
}
requirements_sum=$(sha256sum <"$here/$SEMBLE_REQUIREMENTS" | cut -d' ' -f1)
install_pinned semble \
  "$requirements_sum $SEMBLE_MODEL_REVISION $UV_TAG" semble_tool
exit 0
