#!/bin/sh
# Image build, as root: stage the hooks, which the lifecycle commands run as the
# remote user, and create the mount point. The staged directory is also the
# presence marker other Features check.
id=claude-code
dest=/usr/local/share/enchantments/$id
mount=/mnt/enchantments/claude-data

# defaultFeatures reaches every image, so an unsupported one must still build.
if [ ! -f /etc/debian_version ] || ! command -v bash >/dev/null 2>&1; then
  echo "Warning: $id needs a Debian-based image with bash; nothing installed" \
    >&2
  exit 0
fi

# A fresh named volume copies its mount point's ownership.
mkdir -p "$mount" \
  && chown "$_REMOTE_USER:$(id -gn "$_REMOTE_USER")" "$mount"
# Dangles until onCreate installs Claude. Another install's claude stays put,
# and postStart reports the pair.
link=/usr/local/bin/claude
[ -e "$link" ] || [ -L "$link" ] \
  || ln -s "$_REMOTE_USER_HOME/.local/bin/claude" "$link"

here=$(dirname "$0")
rm -rf "$dest"
if ! { mkdir -p "$dest" && cp "$here"/*.sh "$dest"/ \
  && rm "$dest/install.sh"; }; then
  echo "Warning: $id could not stage its hooks; nothing installed" >&2
  rm -rf "$dest"
fi
exit 0
