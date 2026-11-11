# shellcheck shell=bash disable=SC2034
# This Feature's pins: one single-quoted NAME='value' per line under its
# "# pin <kind> <tool>" header, so tooling can parse the file without running
# it. Asset names are templates: {tag} is the tag, {version} the tag without
# its leading v.

# pin asset stripe-cli repo=stripe/stripe-cli
STRIPE_TAG='v1.55.8'
STRIPE_ASSET_X86_64='stripe_{version}_linux_x86_64.tar.gz'
STRIPE_SHA256_X86_64='a5ee5994bc87f1e9a5557dfb25f6f34d52fc7081756efa4da2d695581c671aec'
STRIPE_ASSET_AARCH64='stripe_{version}_linux_arm64.tar.gz'
STRIPE_SHA256_AARCH64='55bf211b2fcd5f58d751f238b518a8f661b4be612d68595d30db420dad961fe7'
