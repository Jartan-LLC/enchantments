# shellcheck shell=bash
# Vendored into each Feature that uses it; edit it here, then run `make vendor`.

# Hooks must exit 0, or every later lifecycle stage is skipped, so each Feature records its
# failures here and its postStart hook reports them after the project's own output.
enchantments_failures_dir="$HOME/.cache/enchantments"

record_failure() {  # id  message
    echo "Warning: $1: $2" >&2
    mkdir -p "$enchantments_failures_dir" \
        && printf '%s\n' "$2" >>"$enchantments_failures_dir/$1.failures"
}

report_failures() {  # id
    local file="$enchantments_failures_dir/$1.failures"
    [ -s "$file" ] || return 0
    {
        echo "enchantments: $1 reported problems:"
        sed 's/^/  - /' "$file"
        echo "  Each hook can be re-run as you: bash /usr/local/share/enchantments/$1/<hook>.sh"
        echo "  (updateContent.sh from the workspace folder)"
        echo "  Troubleshooting: https://github.com/Jartan-LLC/enchantments/blob/main/docs/troubleshooting.md"
    } >&2
    mv -f "$file" "$file.reported"
}
