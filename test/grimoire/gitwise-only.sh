#!/bin/bash
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

local_plugins() {
  claude plugins list --json | jq -c --arg p "$PWD" '[.[]
    | select(.scope == "local" and .projectPath == $p
      and (.id | endswith("@grimoire")))
    | .id] | sort'
}

check "exactly the plugins option's list is installed" \
  test "$(local_plugins)" = '["gitwise@grimoire"]'
check "no failures recorded" \
  test -z "$(ls "$HOME"/.cache/enchantments/*.failures* 2>/dev/null)"
# VS Code runs the hook with a terminal on stdin: script gives it one. script
# itself reads /dev/null, since a terminal there would stop it under timeout.
# A rerun with one still finishes and records no failure.
check "a rerun finishes with a terminal on stdin" timeout 200 script -qec \
  "bash /usr/local/share/enchantments/grimoire/updateContent.sh" /dev/null \
  </dev/null
# grep prints a recorded failure, if any, into the test log.
check "the rerun records no failure" \
  bash -c "! grep -H . $HOME/.cache/enchantments/*.failures 2>/dev/null"

reportResults
