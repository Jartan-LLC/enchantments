#!/bin/bash
# postStartCommand, as the remote user: when plugins were asked for, check that
# their hooks can find node, then report what the create-time hooks recorded.
# node is checked here, not at create, because a Feature or an apt install in
# the project's postCreateCommand may add it.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
plugins=''
# shellcheck source=/dev/null # written by install.sh
. "$here/options.sh"
id=grimoire

if [ -n "$plugins" ] && ! command -v node >/dev/null; then
  record_failure "$id" "grimoire's plugin hooks need node on PATH"
fi
report_failures "$id"
