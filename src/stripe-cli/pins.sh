# shellcheck shell=bash disable=SC2034
# This Feature's pins: one single-quoted NAME='value' per line under its
# "# pin <kind> <tool>" header, so tooling can parse the file without running
# it. Asset names are templates: {tag} is the tag, {version} the tag without
# its leading v.

# pin asset stripe-cli repo=stripe/stripe-cli
STRIPE_TAG='v1.55.6'
STRIPE_ASSET_X86_64='stripe_{version}_linux_x86_64.tar.gz'
STRIPE_SHA256_X86_64='1759a13a0c48f15e11979696df7b5958a73a8e6c1b92bea2a3ccb73ea97d5854'
STRIPE_ASSET_AARCH64='stripe_{version}_linux_arm64.tar.gz'
STRIPE_SHA256_AARCH64='a676e88cf1dd87351f9d7f907446b9d79ca832ff3b9ba1c178687923e7d05001'
