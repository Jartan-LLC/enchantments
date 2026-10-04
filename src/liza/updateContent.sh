#!/bin/bash
# updateContentCommand, as the remote user, in the workspace: the activation
# sequence. Setting up the volume always runs; the steps that act on a clone
# need one.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=activation-steps.sh
. "$here/activation-steps.sh"
# claude switches a terminal stdin to raw mode, changing the terminal the hook
# runs in. Hooks read no input.
exec </dev/null

liza_volume_ready "Liza isn't set up or activated" || exit 0
[ -x "$liza_bin" ] || exit 0 # onCreate recorded why
in_repo=false
find_clone && in_repo=true
$in_repo && remove_context7_without_toolchain
configure_toolchain
set_up_liza
unlink_global_skills
# shellcheck disable=SC2119 # no extra liza init arguments at create
$in_repo && activate_clone
exit 0
