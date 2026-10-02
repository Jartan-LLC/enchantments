#!/bin/bash
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

# This image has a system Python 3.12 on PATH; semble's venv must still use
# the interpreter uv downloaded into the volume.
in_volume() {
  local python
  python=$(readlink -f ~/.liza/lib/semble/bin/python)
  [[ "$python" == /mnt/enchantments/liza/lib/python/* ]]
}
check "semble's interpreter is in the volume" in_volume
# Offline, so it answers only from the pinned local model.
semble_answers() {
  # shellcheck source=/dev/null # written at create time
  (. ~/.liza/toolchain/env.sh \
    && HF_HUB_OFFLINE=1 semble search python "$PWD" --content all \
    | jq -e '.results | length > 0' >/dev/null)
}
check "semble answers from the local model" semble_answers
check "no failures recorded" \
  test -z "$(ls "$HOME"/.cache/enchantments/*.failures* 2>/dev/null)"

reportResults
