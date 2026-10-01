#!/bin/bash
# onCreateCommand, as the remote user: link ~/.claude and ~/.claude.json into
# claude-data, so the login and settings persist, then install Claude Code with
# Anthropic's native installer. Unpinned on purpose: it updates itself.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
# shellcheck source=fix_volume_owner.sh
. "$here/fix_volume_owner.sh"
# shellcheck source=link_home.sh
. "$here/link_home.sh"
id=claude-code
mount=/mnt/enchantments/claude-data
retry="move it aside, then run: bash $here/onCreate.sh"

fix_volume_owner "$mount" \
  || record_failure "$id" "can't take ownership of $mount without" \
    "passwordless sudo; run: sudo chown -R $(id -un) $mount"
link_home "$HOME/.claude" "$mount" \
  || record_failure "$id" "$HOME/.claude is in the way of claude-data; $retry"

# Containers share the volume and may seed it at once: write aside, then move
# into place only if nothing is there yet.
if [ ! -e "$mount/claude.json" ] \
  && seed=$(mktemp "$mount/.claude.json.XXXXXX"); then
  echo '{}' >"$seed" && mv -n "$seed" "$mount/claude.json"
  rm -f "$seed"
fi
if [ ! -f "$mount/claude.json" ]; then
  record_failure "$id" "can't create $mount/claude.json, so Claude's" \
    "settings won't persist"
elif ! link_home "$HOME/.claude.json" "$mount/claude.json"; then
  record_failure "$id" "$HOME/.claude.json is in the way of claude-data; $retry"
fi

install_claude() {
  local script rc
  script=$(mktemp) || return 1
  curl -fsSL --connect-timeout 15 --max-time 60 https://claude.ai/install.sh \
    -o "$script" \
    && timeout 900 bash "$script" </dev/null
  rc=$?
  rm -f "$script"
  return "$rc"
}
# A network blip during create would otherwise cost a rebuild.
if ! { install_claude || install_claude; } \
  || [ ! -x "$HOME/.local/bin/claude" ]; then
  record_failure "$id" "Claude Code install failed; retry:" \
    "curl -fsSL https://claude.ai/install.sh | bash"
fi
