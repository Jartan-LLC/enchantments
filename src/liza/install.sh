#!/bin/sh
# Image build, as root: stage the hooks and scripts, which the lifecycle
# commands run as the remote user, and create the mount point. The staged
# directory is also the presence marker other Features check.
id=liza
dest=/usr/local/share/enchantments/$id
mount=/mnt/enchantments/liza

# defaultFeatures reaches every image, so an unsupported one must still build.
if [ ! -f /etc/debian_version ] || ! command -v bash >/dev/null 2>&1; then
  echo "Warning: $id needs a Debian-based image with bash; nothing installed" \
    >&2
  exit 0
fi

# A fresh named volume copies its mount point's ownership.
mkdir -p "$mount" \
  && chown "$_REMOTE_USER:$(id -gn "$_REMOTE_USER")" "$mount"
# Dangle until onCreate writes the wrappers.
for name in liza liza-activate liza-deactivate; do
  link=/usr/local/bin/$name
  [ -e "$link" ] || [ -L "$link" ] \
    || ln -s "$_REMOTE_USER_HOME/.local/bin/$name" "$link"
done

here=$(dirname "$0")
rm -rf "$dest"
if ! { mkdir -p "$dest" && cp "$here"/*.sh "$here"/*.jq \
  "$here/AGENT_TOOLS.minimal.md" "$dest"/ && rm "$dest/install.sh"; }; then
  echo "Warning: $id could not stage its hooks; nothing installed" >&2
  rm -rf "$dest"
fi
exit 0
