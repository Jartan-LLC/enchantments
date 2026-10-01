#!/bin/sh
# Image build, as root: stage this Feature's hooks, which the lifecycle commands run as the
# remote user, and create the mount point. The staged directory is also the presence marker
# other Features check.
id=claude-code
dest=/usr/local/share/enchantments/$id

# defaultFeatures reaches every image, so an unsupported one must still build.
if [ ! -f /etc/debian_version ] || ! command -v bash >/dev/null 2>&1; then
    echo "Warning: $id needs a Debian-based image with bash; nothing installed" >&2
    exit 0
fi

# A fresh named volume copies its mount point's ownership. Mount targets are literal
# /home/vscode paths, so on other images the mount creates them and the hooks only warn.
if [ "$_REMOTE_USER_HOME" = /home/vscode ] && [ ! -d "$_REMOTE_USER_HOME/.claude" ]; then
    mkdir "$_REMOTE_USER_HOME/.claude" \
        && chown "$_REMOTE_USER:$(id -gn "$_REMOTE_USER")" "$_REMOTE_USER_HOME/.claude"
fi

here=$(dirname "$0")
rm -rf "$dest"
if ! { mkdir -p "$dest" && cp "$here"/*.sh "$dest"/ && rm "$dest/install.sh"; }; then
    echo "Warning: $id could not stage its hooks; nothing installed" >&2
    rm -rf "$dest"
fi
exit 0
