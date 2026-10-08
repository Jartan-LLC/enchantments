# shellcheck shell=bash disable=SC2034
# This Feature's pins: one single-quoted NAME='value' per line under its
# "# pin <kind> <tool>" header, so tooling can parse the file without running
# it.

# pin asset direnv repo=direnv/direnv
DIRENV_TAG='v2.37.1'
DIRENV_ASSET_X86_64='direnv.linux-amd64'
DIRENV_SHA256_X86_64='1f1b93dd6f38523fde26dfac96151ef9d31a374e3005cd3345fb93555ae0c9b5'
DIRENV_ASSET_AARCH64='direnv.linux-arm64'
DIRENV_SHA256_AARCH64='2a9cef8d73521d6a3ec3f2871c4b747b8c4cc038628c1b57a7efa42b393a2d82'
