#!/bin/bash
# updateContentCommand, as the remote user, in the workspace: add the grimoire
# marketplace and install the plugins at local scope, keyed to this clone. User
# scope would reach every container sharing claude-data; project scope would
# change a tracked file.
# shellcheck source-path=SCRIPTDIR
set -u
here=$(dirname "$(readlink -f "$0")")
# shellcheck source=record_failure.sh
. "$here/record_failure.sh"
# shellcheck source=claude_ready.sh
. "$here/claude_ready.sh"
plugins='' plugins_invalid=''
# shellcheck source=/dev/null # written by install.sh
. "$here/options.sh"
id=grimoire
retry="retry from the workspace folder: bash $here/updateContent.sh"
# claude switches a terminal stdin to raw mode, which stops it outside the
# terminal's foreground process group, as under timeout. Hooks read no input.
exec </dev/null

if [ -n "$plugins_invalid" ]; then
  record_failure "$id" "the plugins option must be comma-separated plugin" \
    "names; nothing installed"
  exit 0
elif [ -z "$plugins" ]; then
  exit 0
elif ! claude_ready "$id" "no plugins installed"; then
  exit 0
elif ! command -v jq >/dev/null; then
  record_failure "$id" "jq isn't installed, so declined plugins can't be" \
    "read: no plugins installed"
  exit 0
fi

# The local settings file is per clone, so git status stays clean. Liza records
# its own slashed line, and removes only that, so the two never collide.
line=.claude/settings.local.json
if exclude=$(git rev-parse --git-path info/exclude 2>/dev/null) \
  && ! grep -qxF "$line" "$exclude" 2>/dev/null; then
  {
    mkdir -p "$(dirname "$exclude")" \
      && { [ ! -s "$exclude" ] || [ -z "$(tail -c1 "$exclude")" ] \
        || echo >>"$exclude"; } \
      && echo "$line" >>"$exclude"
  } || record_failure "$id" "couldn't add $line to $exclude"
fi

# Claude keeps both settings files at the repo root, even for a workspace in a
# subfolder.
settings=$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.claude

# A repo declines a plugin by committing it as false, a clone by `claude plugins
# disable --scope local`. Reinstalling would set the clone's key back to true,
# so neither is touched.
declined() { # plugin
  local file
  for file in "$settings/settings.json" "$settings/settings.local.json"; do
    [ -f "$file" ] \
      && jq -e --arg k "$1@$id" '.enabledPlugins[$k] == false' "$file" \
        >/dev/null 2>&1 \
      && return 0
  done
  return 1
}

# A repo that pins this marketplace to a ref keeps it: a local declaration
# without one would follow the default branch instead. A ref for a fork or
# another source names a commit this repo may not have.
ref=$(jq -r '.extraKnownMarketplaces.grimoire.source
  | select(.repo // "" | ascii_downcase == "jartan-llc/grimoire")
  | .ref // empty' \
  "$settings/settings.json" 2>/dev/null)
# Runs claude for up to 300 seconds, discarding its output. On failure, passes
# its error output on to stderr and prints why: the last error line, the exit
# status when there's none, or that it timed out or was killed.
run_claude() { # claude-args...
  local out status
  out=$(timeout -k 10 300 "$claude_bin" "$@" 2>&1 >/dev/null)
  status=$?
  [ "$status" = 0 ] && return 0
  [ -z "$out" ] || printf '%s\n' "$out" >&2
  case $status in
    124) echo "timed out" ;;
    137) echo "killed, or timed out" ;;
    *)
      out=${out##*$'\n'}
      echo "${out:-exit $status}"
      ;;
  esac
  return 1
}

if ! why=$(run_claude plugins marketplace add \
  "Jartan-LLC/grimoire${ref:+#$ref}" --scope local); then
  record_failure "$id" "adding the grimoire marketplace failed ($why); $retry"
  exit 0
fi
IFS=, read -ra wanted <<<"$plugins"
for plugin in "${wanted[@]}"; do
  declined "$plugin" && continue
  why=$(run_claude plugins install "$plugin@$id" --scope local) \
    || record_failure "$id" "installing $plugin failed ($why); $retry"
done
