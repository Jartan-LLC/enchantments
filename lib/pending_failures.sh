# shellcheck shell=bash
# make vendor copies this into each Feature that uses it: edit
# lib/pending_failures.sh, not a copy. Needs record_failure.sh.

# Succeeds while the id has failures not yet reported. A start-time check then
# records nothing: what it would find, they already explain.
pending_failures() { # id
  # shellcheck disable=SC2154 # set by record_failure.sh
  [ -s "$enchantments_failures_dir/$1.failures" ]
}
