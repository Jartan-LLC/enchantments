#!/bin/sh
# Image build, as root: stage the hooks, which the lifecycle commands run as the
# remote user.
id=codebase-memory-mcp
dest=/usr/local/share/enchantments/$id

# defaultFeatures reaches every image, so an unsupported one must still build.
if [ ! -f /etc/debian_version ] || ! command -v bash >/dev/null 2>&1; then
  echo "Warning: $id needs a Debian-based image with bash; nothing installed" \
    >&2
  exit 0
fi

# Dangles until onCreate installs the binary.
link=/usr/local/bin/$id
[ -e "$link" ] || [ -L "$link" ] \
  || ln -s "$_REMOTE_USER_HOME/.local/bin/$id" "$link"

here=$(dirname "$0")
rm -rf "$dest"
if ! { mkdir -p "$dest" && cp "$here"/*.sh "$dest"/ \
  && rm "$dest/install.sh"; }; then
  echo "Warning: $id could not stage its hooks; nothing installed" >&2
  rm -rf "$dest"
fi
exit 0
