#!/bin/bash
# postStartCommand, as the remote user: check what onCreate set up, then report
# what the hooks recorded.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
# shellcheck source=start_checks.sh
. "$here/start_checks.sh"
id=liza
mount=/mnt/enchantments/liza
rg=$HOME/.local/bin/rg
retry="run: bash $here/onCreate.sh"

# A later step can replace or remove a link. On an architecture onCreate
# doesn't install for, it linked nothing, and said so.
case "$(uname -m)" in
  x86_64 | amd64 | aarch64 | arm64) supported=true ;;
  *) supported=false ;;
esac
if "$supported" && ! pending_failures "$id"; then
  if [ ! -e "$HOME/.liza" ] && [ ! -L "$HOME/.liza" ]; then
    record_at_start "$id" "$HOME/.liza is missing, so Liza and its" \
      "toolchain aren't there; $retry"
  elif [ ! "$HOME/.liza" -ef "$mount" ]; then
    record_at_start "$id" "$HOME/.liza isn't the liza volume, so Liza and" \
      "its toolchain aren't there; move it aside, then $retry"
  elif [ ! -e "$rg" ] && [ ! -L "$rg" ]; then
    record_at_start "$id" "$rg is missing; $retry"
  elif ! "$rg" --version >/dev/null 2>&1; then
    record_at_start "$id" "$rg doesn't run; fix or remove it, then $retry"
  fi
fi
report_failures "$id"
