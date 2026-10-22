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
# Gives a checkout a stub devcontainer CLI, where ghcr_lib.sh looks for it:
# a Feature's :1 lists each version GHCR_TAGS gives as <id>@<version>, and a
# lookup of an id in GHCR_DOWN fails.
with_registry() { # [dir]
  local bin=${1:-.}/node_modules/.bin
  mkdir -p "$bin"
  cat >"$bin/devcontainer" <<'EOF'
#!/bin/bash
id=${4%:1}
id=${id##*/}
for d in ${GHCR_DOWN:-}; do
  [ "$d" != "$id" ] || { echo "[t] 503 from ghcr.io for $id" >&2 && exit 1; }
done
for p in ${GHCR_TAGS:-}; do
  [ "${p%@*}" != "$id" ] || echo "${p#*@}"
done | jq -R . | jq -s '{publishedTags: (["1", "latest"] + .)}'
EOF
  chmod +x "$bin/devcontainer"
}
