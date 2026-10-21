# shellcheck shell=bash disable=SC2034
# This Feature's pins: one single-quoted NAME='value' per line under its
# "# pin <kind> <tool>" header, so tooling can parse the file without running
# it. The npm tools are pinned by npm/package-lock.json, which Dependabot
# updates.

# pin asset ast-grep repo=ast-grep/ast-grep
AST_GREP_TAG='0.50.0'
AST_GREP_ASSET_X86_64='app-x86_64-unknown-linux-gnu.zip'
AST_GREP_SHA256_X86_64='0fd3f489639abb8465a914b74b8779171577582318d8a940d00399f59dba81c5'
AST_GREP_ASSET_AARCH64='app-aarch64-unknown-linux-gnu.zip'
AST_GREP_SHA256_AARCH64='3a4ad22dd1dca7a4900a173de65885578617af57fa13dd93b8d345d6b352770e'

# pin asset yq repo=mikefarah/yq
YQ_TAG='v4.54.1'
YQ_ASSET_X86_64='yq_linux_amd64'
YQ_SHA256_X86_64='8e34fc298390875de416e6a4afcb8cabeceb25d9aa8506c1a2f9353cf702ea5f'
YQ_ASSET_AARCH64='yq_linux_arm64'
YQ_SHA256_AARCH64='189088da0c6429ec5178dfaab1a114805f6cab0b61b165ab236efedf1d57a71b'

# pin asset rtk repo=rtk-ai/rtk
RTK_TAG='v1.0.0'
RTK_ASSET_X86_64='rtk-x86_64-unknown-linux-musl.tar.gz'
RTK_SHA256_X86_64='b0b69fbed72f55d8eae18587c0b6bc140a8a8b39d5b7c6e6df33795249940926'
RTK_ASSET_AARCH64='rtk-aarch64-unknown-linux-gnu.tar.gz'
RTK_SHA256_AARCH64='9438c2c99d428fa6fbe7f4d1c01a87babd5feec17ee6d7bb3372a613a21db7d3'

# pin asset mdq repo=yshavit/mdq
MDQ_TAG='v0.10.0'
MDQ_ASSET_X86_64='mdq-linux-x64-musl.tar.gz'
MDQ_SHA256_X86_64='673ed676382f54a21e4381d845236c776b2b71ed8dc1cc3e92cf6d66a39edb07'

# pin asset uv repo=astral-sh/uv
UV_TAG='0.13.1'
UV_ASSET_X86_64='uv-x86_64-unknown-linux-musl.tar.gz'
UV_SHA256_X86_64='6c86040a8f045ab9adc9e3ec4cdafa03fd00e9a988ed2bf28971c7fc2d0debd0'
UV_ASSET_AARCH64='uv-aarch64-unknown-linux-musl.tar.gz'
UV_SHA256_AARCH64='345a8308e4d1835cdfaadf692836fd3137a6d45864773f05ad7bf59442b1ba16'

# pin tag-commit scip-search repo=liza-mas/scip-search
SCIP_SEARCH_TAG='v0.3.0'
SCIP_SEARCH_COMMIT='16384a7564ec9b5cf93580c26e4a76618242ee53'

# pin branch-commit stacklit repo=liza-mas/stacklit-cli
STACKLIT_COMMIT='3c0e04153fe10dde2eeb4ddff72417c7621d5436'

# pin branch-commit functional-clusters repo=liza-mas/functional-clusters
FUNCTIONAL_CLUSTERS_COMMIT='f1ac506508752660214d4a6d35fd33113177a482'

# pin branch-commit mdtoc repo=liza-mas/mdtoc
MDTOC_COMMIT='37712275e36b5aef9c9651e633b1896e22d917f3'

# pin branch-commit bash-policy repo=liza-mas/bash-policy
BASH_POLICY_COMMIT='7260ac81da9bbaad89e1737e68239f0f04a7558e'

# pin hf-model semble-model model=minishlab/potion-code-16M-v2
SEMBLE_MODEL_REVISION='e9d2a44ca6a05ac6685f3b23709ea57eb7352d5b'
SEMBLE_MODEL_FILE_CONFIG='config.json'
SEMBLE_MODEL_SHA256_CONFIG='148e5691a6fcc553437156859701fba017a1ba5d340b170f17e0f3668fb861a7'
SEMBLE_MODEL_FILE_MODEL='model.safetensors'
SEMBLE_MODEL_SHA256_MODEL='75cf7a6c2171b230ad19b1e7d8e0b1aee86da5a02af8e7cacedd9921d227623c'
SEMBLE_MODEL_FILE_MODULES='modules.json'
SEMBLE_MODEL_SHA256_MODULES='a68dcbed0429dcdd5bfdca92b0b03cc30d09122c0a3fcf4758787d4b244e45b2'
SEMBLE_MODEL_FILE_TOKENIZER='tokenizer.json'
SEMBLE_MODEL_SHA256_TOKENIZER='107bbdcbad4bff1d299b7a4c3a2fb17c52890688b7dd0e4c9deab79d3c4f3d45'

# pin node node
NODE_VERSION='v24.22.0'
NODE_SHA256_X86_64='28ea0a438de9a13bd7891fd758eee6c7819ee8af5442dfd8d45bd65e56d4228c'
NODE_SHA256_AARCH64='b7e7991d5407815adfa74a2a9cd4db683552c8ce32ff4a295c22e972849c3f5d'

# pin go go
GO_VERSION='1.27.2'
GO_SHA256_X86_64='ecbadb99091a3f46e31f5f934b068b1864eafa7995211b39eaddf76996045fe5'
GO_SHA256_AARCH64='94f3e30b8e374bc285e7dadc11e0865726b9bc6e85b841ccceaabc0214c6b7c8'

# pin uv-lock semble lock=semble-requirements.txt input=semble.in
SEMBLE_REQUIREMENTS='semble-requirements.txt'
