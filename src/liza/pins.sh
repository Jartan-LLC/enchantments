# shellcheck shell=bash disable=SC2034
# This Feature's pins: one single-quoted NAME='value' per line under its
# "# pin <kind> <tool>" header, so tooling can parse the file without running
# it. Asset names are templates: {tag} is the tag, {version} the tag without
# its leading v.

# pin asset liza repo=liza-mas/liza
LIZA_TAG='v0.10.0'
LIZA_COMMIT='5d70efca300e5c00df93063ebde849fc747b7f27'
LIZA_ASSET_X86_64='liza-{version}-linux-amd64.tar.gz'
LIZA_SHA256_X86_64='0b44c5a73f1b4331ce16755c72ac9328c84b21bed0f94a7a207ca746999bf5c5'
LIZA_ASSET_AARCH64='liza-{version}-linux-arm64.tar.gz'
LIZA_SHA256_AARCH64='eda82bb3acdc1944d3ab18622457546b4d900ce7ac134e418404c3e14b7927ca'

# pin asset ripgrep repo=BurntSushi/ripgrep
RG_TAG='15.2.0'
RG_ASSET_X86_64='ripgrep-{version}-x86_64-unknown-linux-musl.tar.gz'
RG_SHA256_X86_64='33e15bcf1624b25cdd2a55813a47a2f95dbe126268203e76aa6a585d1e7b149c'
RG_ASSET_AARCH64='ripgrep-{version}-aarch64-unknown-linux-musl.tar.gz'
RG_SHA256_AARCH64='800b1e7206afe799dfb5a6901f23147cfaabe0e52210538100f61e86e1740915'

# pin asset pre-commit-uv repo=astral-sh/uv
PRE_COMMIT_UV_TAG='0.13.7'
PRE_COMMIT_UV_ASSET_X86_64='uv-x86_64-unknown-linux-musl.tar.gz'
PRE_COMMIT_UV_SHA256_X86_64='287491da03f2a785c70fa75b13e1f849918c2f2b5415fe84876b8214eeb792f9'
PRE_COMMIT_UV_ASSET_AARCH64='uv-aarch64-unknown-linux-musl.tar.gz'
PRE_COMMIT_UV_SHA256_AARCH64='2d3ec076a0c4c0e8250bb6418c44080828b544f1a3be0b6e46adf9fb6923de45'

# pin uv-python pre-commit-python uv=pre-commit-uv
PRE_COMMIT_PYTHON_VERSION='3.12.16'

# pin uv-lock pre-commit lock=pre-commit-requirements.txt input=pre-commit.in
PRE_COMMIT_REQUIREMENTS='pre-commit-requirements.txt'
