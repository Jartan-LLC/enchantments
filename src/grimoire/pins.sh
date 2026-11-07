# shellcheck shell=bash disable=SC2034
# This Feature's pins: one single-quoted NAME='value' per line under its
# "# pin <kind> <tool>" header, so tooling can parse the file without running
# it. A tool name is unique across the Features, since pin-bumps titles its
# issues by tool.

# pin node grimoire-node
NODE_VERSION='v26.13.0'
NODE_SHA256_X86_64='5848553868b402d3fabb5b09270649977780a390f832155721025a08b5104455'
NODE_SHA256_AARCH64='439e9c438acdf6a6ffe47418da709153d66c4bed812e30a473faacb107dd2791'
