#!/bin/sh
# Image build, as root: stage the hooks, which the lifecycle commands run as the
# remote user, with the options.
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
  && rm "$dest/install.sh"; }; then
  echo "Warning: $id could not stage its hooks; nothing installed" >&2
  rm -rf "$dest"
  exit 0
fi

# options.sh is sourced by a hook, so only a validated list is written into it.
# Empty means no plugins.
case ${PLUGINS-} in
  *[!A-Za-z0-9._,-]* | ,* | *, | *,,*)
    echo "plugins_invalid=1" >"$dest/options.sh"
    ;;
  *) printf "plugins='%s'\n" "${PLUGINS-}" >"$dest/options.sh" ;;
esac
exit 0
