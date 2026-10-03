# shellcheck shell=bash
# The test scripts' harness: one "ok" or "FAIL" line per case, and a summary
# whose exit status is the suite's. Sourced.
passed=0
failed=0

pass() { # name
  echo "ok   $1"
  passed=$((passed + 1))
}
fail() { # name detail
  echo "FAIL $1: $2"
  failed=$((failed + 1))
}
# Runs a command and checks its exit status, and that its output contains
# want (when given).
expect() { # name status want command...
  local name=$1 status=$2 want=$3 out rc
  shift 3
  out=$("$@" 2>&1)
  rc=$?
  if [ "$rc" -eq "$status" ] && { [ -z "$want" ] \
    || grep -qF -- "$want" <<<"$out"; }; then
    pass "$name"
  else
    fail "$name" "exit $rc, want $status '$want': $out"
  fi
}
# Runs a command that must succeed without printing unwanted.
expect_not() { # name unwanted command...
  local name=$1 unwanted=$2 out rc
  shift 2
  out=$("$@" 2>&1)
  rc=$?
  if [ "$rc" -eq 0 ] && ! grep -qF -- "$unwanted" <<<"$out"; then
    pass "$name"
  else
    fail "$name" "exit $rc, want 0 without '$unwanted': $out"
  fi
}
summary() {
  echo
  echo "$passed passed, $failed failed"
  [ "$failed" -eq 0 ]
}
