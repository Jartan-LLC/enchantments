# shellcheck shell=bash
# make vendor copies this into each Feature that uses it: edit
# lib/start_checks.sh, not a copy. Needs record_failure.sh.

# Succeeds while the id has failures not yet reported. A postStart check then
# records nothing: a pending failure likely explains what it would find, and
# the next start checks again.
pending_failures() { # id
  # shellcheck disable=SC2154 # set by record_failure.sh
  [ -s "$enchantments_failures_dir/$1.failures" ]
}

# Records a failure without printing it, for a postStart check: the
# report_failures that follows prints it. Where it can't record, it prints.
record_at_start() { # id message...
  local id=$1
  shift
  { mkdir -p "$enchantments_failures_dir" \
    && printf '%s\n' "$*" >>"$enchantments_failures_dir/$id.failures"; } \
    2>/dev/null || echo "Warning: $id: $*" >&2
}
