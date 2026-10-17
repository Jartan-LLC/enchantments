# shellcheck shell=bash disable=SC2034
# This Feature's pins: one single-quoted NAME='value' per line under its
# "# pin <kind> <tool>" header, so tooling can parse the file without running
# it.

# pin asset direnv repo=direnv/direnv
DIRENV_TAG='v2.38.2'
DIRENV_ASSET_X86_64='direnv.linux-amd64'
DIRENV_SHA256_X86_64='148820a187930d36ca6a204504e5cdb30d8396cd1a97e64c3b3f10d793c11247'
DIRENV_ASSET_AARCH64='direnv.linux-arm64'
DIRENV_SHA256_AARCH64='ec2a32dbe2f19dd085bd9315a1b4ea88b55ec288aa7eabe8723490baf466cb23'
