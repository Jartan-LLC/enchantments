#!/bin/bash
# postStartCommand, as the remote user: check what onCreate set up, then report
# what the hooks recorded.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
# shellcheck source=pending_failures.sh
. "$here/pending_failures.sh"
id=liza
mount=/mnt/enchantments/liza

# A later step can replace a link. No ~/.liza at all means onCreate stopped
# before linking it, and said why.
if ! pending_failures "$id" && { [ -e ~/.liza ] || [ -L ~/.liza ]; }; then
  if [ ! "$HOME/.liza" -ef "$mount" ]; then
    record_failure "$id" "$HOME/.liza isn't the liza volume, so Liza and its" \
      "toolchain aren't there; move it aside, then run: bash" \
      "$here/onCreate.sh"
  elif ! "$HOME/.local/bin/rg" --version >/dev/null 2>&1; then
    record_failure "$id" "$HOME/.local/bin/rg doesn't run; remove it, then" \
      "run: bash $here/onCreate.sh"
  fi
fi
report_failures "$id"
