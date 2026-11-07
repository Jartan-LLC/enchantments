#!/bin/sh
# Image build, as root: stage the hooks, which the lifecycle commands run as the
# remote user, with the options, and install the pinned Node when plugins were
# asked for and the image has none.
id=grimoire
dest=/usr/local/share/enchantments/$id

# defaultFeatures reaches every image, so an unsupported one must still build.
if [ ! -f /etc/debian_version ] || ! command -v bash >/dev/null 2>&1; then
  echo "Warning: $id needs a Debian-based image with bash; nothing installed" \
    >&2
  exit 0
fi

here=$(dirname "$0")
rm -rf "$dest"
if ! { mkdir -p "$dest" && cp "$here"/*.sh "$dest"/ \
  && rm "$dest"/install*.sh "$dest/fetch_verified.sh" "$dest/pins.sh"; }; then
  echo "Warning: $id could not stage its hooks; nothing installed" >&2
  rm -rf "$dest"
  exit 0
fi

# options.sh is sourced by a hook, so only a validated list is written into it.
# Empty means no plugins.
case ${PLUGINS-} in
  *[!A-Za-z0-9._,-]* | ,* | *, | *,,*)
    echo "plugins_invalid=1" >"$dest/options.sh"
    plugins=
    ;;
  *)
    printf "plugins='%s'\n" "${PLUGINS-}" >"$dest/options.sh"
    plugins=${PLUGINS-}
    ;;
esac

# The plugins' hooks run node. installsAfter orders the node Feature first, so
# its Node is on PATH by now; this one goes last on PATH, so a project's Node
# still wins. $dest/bin is already on PATH here, but the rm above emptied it.
if [ -n "$plugins" ] && ! command -v node >/dev/null 2>&1; then
  bash "$here/install_node.sh" "$dest" \
    || echo "Warning: $id could not install Node; the plugins' hooks" \
      "can't run until node is on PATH" >&2
fi
exit 0
