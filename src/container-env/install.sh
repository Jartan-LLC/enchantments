#!/bin/sh
# Image build, as root: create the mount point, stage the hooks and the
# loader, hook the loader into login shells, and install the pinned direnv.
id=container-env
dest=/usr/local/share/enchantments/$id
mount=/mnt/enchantments/container-env

# defaultFeatures reaches every image, so an unsupported one must still build.
if [ ! -f /etc/debian_version ] || ! command -v bash >/dev/null 2>&1; then
  echo "Warning: $id needs a Debian-based image with bash; nothing installed" \
    >&2
  exit 0
fi

# A fresh named volume copies its mount point's ownership.
mkdir -p "$mount" \
  && chown "$_REMOTE_USER:$(id -gn "$_REMOTE_USER")" "$mount"

here=$(dirname "$0")
rm -rf "$dest"
if ! { mkdir -p "$dest" && cp "$here"/*.sh "$dest"/ \
  && rm "$dest"/install*.sh "$dest/fetch_verified.sh" "$dest/pins.sh" \
    "$dest/profile.sh"; }; then
  echo "Warning: $id could not stage its hooks; nothing installed" >&2
  rm -rf "$dest"
  exit 0
fi
cp "$here/profile.sh" /etc/profile.d/container-env.sh \
  || echo "Warning: $id could not hook login shells; nothing loads" >&2

# Built in, not fetched at create, so every user's login shell can run it.
# Without it, per-variable files still load, and postStart says the .env
# can't.
bash "$here/install_direnv.sh" "$dest/direnv" \
  || echo "Warning: $id could not install direnv; a .env won't load" >&2
exit 0
