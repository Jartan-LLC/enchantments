#!/bin/bash
# liza-activate: activates Liza for the clone around the working directory,
# as container create does. Arguments go to liza init. Exits non-zero when it
# recorded a failure.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=activation-steps.sh
. "$here/activation-steps.sh"

recorded() { cat "$enchantments_failures_dir/liza.failures" 2>/dev/null; }
before=$(recorded)
liza_volume_ready "Liza isn't activated" || exit 1
find_clone || exit 1
remove_toolchain_registration
activate_clone "$@"
[ "$(recorded)" = "$before" ]
