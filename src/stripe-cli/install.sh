#!/bin/sh
# Image build, as root: create the mount point, stage the hooks, which the
# lifecycle commands run as the remote user, and install the pinned stripe.
id=stripe-cli
dest=/usr/local/share/enchantments/$id
mount=/mnt/enchantments/stripe-config

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
  && rm "$dest"/install*.sh "$dest/fetch_verified.sh" "$dest/pins.sh"; }; then
  echo "Warning: $id could not stage its hooks; nothing installed" >&2
  rm -rf "$dest"
  exit 0
fi

# Built in, not fetched at create, so every user's PATH has it; postStart
# says so while it's missing.
bash "$here/install_stripe.sh" /usr/local/bin/stripe \
  || echo "Warning: $id could not install stripe" >&2
exit 0
