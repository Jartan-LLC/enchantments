# shellcheck shell=bash disable=SC2034
# This Feature's pins: one single-quoted NAME='value' per line under its
# "# pin <kind> <tool>" header, so tooling can parse the file without running
# it. A tool name is unique across the Features, since pin-bumps titles its
# issues by tool.

# pin node grimoire-node
NODE_VERSION='v26.13.1'
NODE_SHA256_X86_64='518674de2b621728a5e4486f5fb3b7d2900bb3cc4aa97969edaa463db99f9778'
NODE_SHA256_AARCH64='80a330b35415382878df18d41afbd106ea89bfb3be0087d6608e289a14c5cc7d'
