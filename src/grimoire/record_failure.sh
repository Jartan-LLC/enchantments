# shellcheck shell=bash
# make vendor copies this into each Feature that uses it: edit
# lib/record_failure.sh, not a copy.

# Hooks must exit 0, or every later lifecycle stage is skipped, so each Feature
# records its failures here and its postStart hook reports them after the
# project's own output.
enchantments_failures_dir="$HOME/.cache/enchantments"

# The message's words are joined with spaces, so a long one can span lines.
record_failure() { # id message...
  local id=$1
  shift
  echo "Warning: $id: $*" >&2
  mkdir -p "$enchantments_failures_dir" \
    && printf '%s\n' "$*" >>"$enchantments_failures_dir/$id.failures"
}

report_failures() { # id
  local file="$enchantments_failures_dir/$1.failures"
  local docs=https://github.com/Jartan-LLC/enchantments/blob/main/docs
  [ -s "$file" ] || return 0
  {
    echo "enchantments: $1 reported problems:"
    sed 's/^/  - /' "$file"
    echo "  Re-run a hook as you, from the workspace folder:"
    echo "    bash /usr/local/share/enchantments/$1/<hook>.sh"
    echo "  Troubleshooting: $docs/troubleshooting.md"
  } >&2
  mv -f "$file" "$file.reported"
}
