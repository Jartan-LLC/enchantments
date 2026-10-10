# shellcheck shell=bash disable=SC2034
# This Feature's pins: one single-quoted NAME='value' per line under its
# "# pin <kind> <tool>" header, so tooling can parse the file without running
# it. The npm tools are pinned by npm/package-lock.json, which Dependabot
# updates.

# pin asset ast-grep repo=ast-grep/ast-grep
AST_GREP_TAG='0.45.3'
AST_GREP_ASSET_X86_64='app-x86_64-unknown-linux-gnu.zip'
AST_GREP_SHA256_X86_64='f8ac830881339d1edee6b2652f54798c0f4da5a827f2db38a08ee31117783ce8'
AST_GREP_ASSET_AARCH64='app-aarch64-unknown-linux-gnu.zip'
AST_GREP_SHA256_AARCH64='b39cfbc58da4b869a88b8a4bc57bd5deb0d24541e704cf7c257da7b53ec81c8f'

# pin asset yq repo=mikefarah/yq
YQ_TAG='v4.54.1'
YQ_ASSET_X86_64='yq_linux_amd64'
YQ_SHA256_X86_64='8e34fc298390875de416e6a4afcb8cabeceb25d9aa8506c1a2f9353cf702ea5f'
YQ_ASSET_AARCH64='yq_linux_arm64'
YQ_SHA256_AARCH64='189088da0c6429ec5178dfaab1a114805f6cab0b61b165ab236efedf1d57a71b'

# pin asset rtk repo=rtk-ai/rtk
RTK_TAG='v0.51.0'
RTK_ASSET_X86_64='rtk-x86_64-unknown-linux-musl.tar.gz'
RTK_SHA256_X86_64='5028d3b19a8f0990d30fec9fbb07e32782bc5698e618fb1861aad8a9ccba4eb5'
RTK_ASSET_AARCH64='rtk-aarch64-unknown-linux-gnu.tar.gz'
RTK_SHA256_AARCH64='8d6d1aad9e69b42481eda7039507d1f7ee93698f87713cecd873d287c1931632'

# pin asset mdq repo=yshavit/mdq
MDQ_TAG='v0.10.0'
MDQ_ASSET_X86_64='mdq-linux-x64-musl.tar.gz'
MDQ_SHA256_X86_64='673ed676382f54a21e4381d845236c776b2b71ed8dc1cc3e92cf6d66a39edb07'

# pin asset uv repo=astral-sh/uv
UV_TAG='0.12.22'
UV_ASSET_X86_64='uv-x86_64-unknown-linux-musl.tar.gz'
UV_SHA256_X86_64='a50fd68c653b0cfb1c85e0a7db62cb78cf5c22b6f3dcf3ae173e5f222d084470'
UV_ASSET_AARCH64='uv-aarch64-unknown-linux-musl.tar.gz'
UV_SHA256_AARCH64='228bd32c180421a94eef91378a92b2dd63c768bd278430e833250524c4a13382'

# pin tag-commit scip-search repo=liza-mas/scip-search
SCIP_SEARCH_TAG='v0.2.1'
SCIP_SEARCH_COMMIT='b8c1487bb4cbdb6483a61c376b81eb3d77d8cc1f'

# pin branch-commit stacklit repo=liza-mas/stacklit-cli
STACKLIT_COMMIT='c8a87a75116e675f67e5ca71197b6deee55142b2'

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
NODE_VERSION='v24.21.0'
NODE_SHA256_X86_64='6e1db87ef58b8819e5d5402eff1536491b18edd8eb7bee5ef7897876e88dc5ff'
NODE_SHA256_AARCH64='724282c3b43aec998aa9527380465b45d229e021b58035f5f4f63095eabfe5d5'

# pin go go
GO_VERSION='1.27.1'
GO_SHA256_X86_64='63d339f0da5ab53635a56f2490a7984dfe12dfcff22ad749f63edaf590168445'
GO_SHA256_AARCH64='3450b45a3f9ee8568792736a5c5e70a1f2e9b36c35a8f74958c03e51d7d92bec'

# pin uv-lock semble lock=semble-requirements.txt input=semble.in
SEMBLE_REQUIREMENTS='semble-requirements.txt'
