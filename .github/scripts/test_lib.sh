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
# Succeeds when text holds want whole: its lines together, in order. A
# multi-line want in expect matches any one of its lines.
holds() { # text want
  [[ $1 == *"$2"* ]]
}
summary() {
  echo
  echo "$passed passed, $failed failed"
  [ "$failed" -eq 0 ]
}
# Gives a checkout a stub devcontainer CLI, where ghcr_lib.sh looks for it:
# a Feature's :1 lists each version GHCR_TAGS gives as <id>@<version>. A
# lookup of an id in GHCR_DOWN fails, and so does one of an id with no
# version, as GHCR's 403 for a package never published does. One of an id in
# GHCR_GARBLED prints what isn't JSON.
with_registry() { # [dir]
  local bin=${1:-.}/node_modules/.bin
  mkdir -p "$bin"
  cat >"$bin/devcontainer" <<'EOF'
#!/bin/bash
id=${4%:1}
id=${id##*/}
for g in ${GHCR_GARBLED:-}; do
  [ "$g" != "$id" ] || { echo '{"publ' && exit 0; }
done
for d in ${GHCR_DOWN:-}; do
  [ "$d" != "$id" ] || { echo "[t] 503 from ghcr.io for $id" >&2 && exit 1; }
done
tags=$(for p in ${GHCR_TAGS:-}; do
  [ "${p%@*}" != "$id" ] || echo "${p#*@}"
done)
[ -n "$tags" ] || { echo "[t] 403: access to $id is denied" >&2 && exit 1; }
jq -R . <<<"$tags" | jq -s '{publishedTags: (["1", "latest"] + .)}'
EOF
  chmod +x "$bin/devcontainer"
}
