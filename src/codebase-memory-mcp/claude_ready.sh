# shellcheck shell=bash
# make vendor copies this into each Feature that uses it: edit
# lib/claude_ready.sh, not a copy.

# claude-code's layout, which the Features that use Claude rely on.
claude_bin=$HOME/.local/bin/claude
claude_json=/mnt/enchantments/claude-data/claude.json

# Succeeds when claude-code's Claude is usable here. Otherwise records why for
# the caller, ending with what the caller skips, and fails. Needs
# record_failure.
claude_ready() { # id consequence
  if [ ! -d /usr/local/share/enchantments/claude-code ]; then
    record_failure "$1" "claude-code absent: $2"
  elif [ ! "$HOME/.claude.json" -ef "$claude_json" ]; then
    record_failure "$1" "$HOME/.claude.json isn't linked into claude-data" \
      "(see claude-code's report): $2"
  elif [ ! -x "$claude_bin" ]; then
    record_failure "$1" "claude isn't installed (see claude-code's report):" \
      "$2"
  else
    return 0
  fi
  return 1
}
