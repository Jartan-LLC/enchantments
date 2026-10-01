#!/bin/sh
# defaultFeatures reaches every image. On one the Features don't support, the image must still
# build and the project's own hooks must still run. No bash here, so no test library either.
set -e
test -f /tmp/project-post-create-ran
test ! -e /usr/local/share/enchantments
echo "alpine: the image built, nothing was staged, and the project's postCreateCommand ran"
