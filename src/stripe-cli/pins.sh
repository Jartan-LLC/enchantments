# shellcheck shell=bash disable=SC2034
# This Feature's pins: one single-quoted NAME='value' per line under its
# "# pin <kind> <tool>" header, so tooling can parse the file without running
# it. Asset names are templates: {tag} is the tag, {version} the tag without
# its leading v.

# pin asset stripe-cli repo=stripe/stripe-cli
STRIPE_TAG='v1.55.11'
STRIPE_ASSET_X86_64='stripe_{version}_linux_x86_64.tar.gz'
STRIPE_SHA256_X86_64='c710bdb63045ea8e4c3d218efe4c269a90a32bd807c1306a29438e54f80bcfdc'
STRIPE_ASSET_AARCH64='stripe_{version}_linux_arm64.tar.gz'
STRIPE_SHA256_AARCH64='026132ef249b838734df3fa21f41d5b637101c09ccb287015f5bd12df60f38fe'
