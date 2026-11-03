# shellcheck shell=bash disable=SC2034
# This Feature's pins: one single-quoted NAME='value' per line under its
# "# pin <kind> <tool>" header, so tooling can parse the file without running
# it. Asset names are templates: {tag} is the tag, {version} the tag without
# its leading v.

# pin asset stripe-cli repo=stripe/stripe-cli
STRIPE_TAG='v1.55.3'
STRIPE_ASSET_X86_64='stripe_{version}_linux_x86_64.tar.gz'
STRIPE_SHA256_X86_64='a894f7891eac5eabb67a5ad5b4820a236626a805b9be544fb4c6e41c5ad91043'
STRIPE_ASSET_AARCH64='stripe_{version}_linux_arm64.tar.gz'
STRIPE_SHA256_AARCH64='52215f1bebf4a86e4221f2eeb62f56e499de4fc0a1b1bcb19a2d3c2bf84d76f2'
