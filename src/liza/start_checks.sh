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
# report_failures that follows prints it.
record_at_start() { # id message...
  record_failure "$@" 2>/dev/null
}
