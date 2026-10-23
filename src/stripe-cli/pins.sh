# shellcheck shell=bash disable=SC2034
# This Feature's pins: one single-quoted NAME='value' per line under its
# "# pin <kind> <tool>" header, so tooling can parse the file without running
# it. Asset names are templates: {tag} is the tag, {version} the tag without
# its leading v.

# pin asset stripe-cli repo=stripe/stripe-cli
STRIPE_TAG='v1.54.0'
STRIPE_ASSET_X86_64='stripe_{version}_linux_x86_64.tar.gz'
STRIPE_SHA256_X86_64='7e8b0693b56b3690bf0bd5d50f1f8a96bd8b84ad4efd1f08c493220b191e074b'
STRIPE_ASSET_AARCH64='stripe_{version}_linux_arm64.tar.gz'
STRIPE_SHA256_AARCH64='1a5fd5a7609ba71bed2bbe20115954b25cf2d36b690b18331e790f4e4882a72a'
