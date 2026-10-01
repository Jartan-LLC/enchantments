#!/bin/bash
# postStartCommand, as the remote user: check that the plugin hooks can find node, then report
# what the create-time hooks recorded. node is checked here, not at create, because a Feature
# or an apt install in the project's postCreateCommand may add it.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
id=grimoire

command -v node >/dev/null || record_failure "$id" "grimoire's plugin hooks need node on PATH"
report_failures "$id"
