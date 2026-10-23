#!/bin/sh
# Image build, as root: stage the postStart hook, which runs as the remote
# user, and install the pinned stripe.
id=stripe-cli
dest=/usr/local/share/enchantments/$id

# defaultFeatures reaches every image, so an unsupported one must still build.
if [ ! -f /etc/debian_version ] || ! command -v bash >/dev/null 2>&1; then
  echo "Warning: $id needs a Debian-based image with bash; nothing installed" \
    >&2
  exit 0
fi

here=$(dirname "$0")
rm -rf "$dest"
if ! { mkdir -p "$dest" && cp "$here/postStart.sh" "$dest"/; }; then
  echo "Warning: $id could not stage its hook; nothing installed" >&2
  rm -rf "$dest"
  exit 0
fi

# Built in, not fetched at create, so every user's PATH has it; postStart
# says so while it's missing.
bash "$here/install_stripe.sh" /usr/local/bin/stripe \
  || echo "Warning: $id could not install stripe" >&2
exit 0
