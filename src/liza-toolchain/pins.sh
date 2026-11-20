# shellcheck shell=bash disable=SC2034
# This Feature's pins: one single-quoted NAME='value' per line under its
# "# pin <kind> <tool>" header, so tooling can parse the file without running
# it. The npm tools are pinned by npm/package-lock.json, which Dependabot
# updates.

# pin asset ast-grep repo=ast-grep/ast-grep
AST_GREP_TAG='0.51.2'
AST_GREP_ASSET_X86_64='app-x86_64-unknown-linux-gnu.zip'
AST_GREP_SHA256_X86_64='40604c21c38d4c7581c56bdddeef277c56bf3c0113620aa96e78ae87e82366df'
AST_GREP_ASSET_AARCH64='app-aarch64-unknown-linux-gnu.zip'
AST_GREP_SHA256_AARCH64='c3ab2bd43959db28621dc1551c13ea5fe5db4c1fc7b18086dade6b65042c78d0'

# pin asset yq repo=mikefarah/yq
YQ_TAG='v4.54.3'
YQ_ASSET_X86_64='yq_linux_amd64'
YQ_SHA256_X86_64='129534601871538efe0ba4c5e62a34fb1d5f469bcb975c4fddeb467d82974973'
YQ_ASSET_AARCH64='yq_linux_arm64'
YQ_SHA256_AARCH64='89f69310b61b68d1245065a1241d1fc843f7a36cd6103ffd77ad987613bd1b67'

# pin asset rtk repo=rtk-ai/rtk
RTK_TAG='v1.2.0'
RTK_ASSET_X86_64='rtk-x86_64-unknown-linux-musl.tar.gz'
RTK_SHA256_X86_64='70fee7b4a548c43dde94c77e2335550981b0bc2fb013691d8c8109b5bd0eda37'
RTK_ASSET_AARCH64='rtk-aarch64-unknown-linux-gnu.tar.gz'
RTK_SHA256_AARCH64='93c1dcd37fd5fcae8fa772a5b5c34a30af142ace4f4081c8f98319146b7a10a4'

# pin asset mdq repo=yshavit/mdq
MDQ_TAG='v0.10.0'
MDQ_ASSET_X86_64='mdq-linux-x64-musl.tar.gz'
MDQ_SHA256_X86_64='673ed676382f54a21e4381d845236c776b2b71ed8dc1cc3e92cf6d66a39edb07'

# pin asset uv repo=astral-sh/uv
UV_TAG='0.13.8'
UV_ASSET_X86_64='uv-x86_64-unknown-linux-musl.tar.gz'
UV_SHA256_X86_64='61fb26dabc4f0cf1d050fc6c67d40e43e4fae2994af21ebc1e050b233bf2b5ed'
UV_ASSET_AARCH64='uv-aarch64-unknown-linux-musl.tar.gz'
UV_SHA256_AARCH64='0c6f8593fcf1eadfc60e663b685c408267559d7c5d61c689bbb9f3a7e369ba32'

# pin tag-commit scip-search repo=liza-mas/scip-search
SCIP_SEARCH_TAG='v0.3.0'
SCIP_SEARCH_COMMIT='16384a7564ec9b5cf93580c26e4a76618242ee53'

# pin branch-commit stacklit repo=liza-mas/stacklit-cli
STACKLIT_COMMIT='d097d2d13c17112638de1e146165dd055470cc10'

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
NODE_VERSION='v26.13.1'
NODE_SHA256_X86_64='518674de2b621728a5e4486f5fb3b7d2900bb3cc4aa97969edaa463db99f9778'
NODE_SHA256_AARCH64='80a330b35415382878df18d41afbd106ea89bfb3be0087d6608e289a14c5cc7d'

# pin go go
GO_VERSION='1.27.4'
GO_SHA256_X86_64='7226736c2339719cda28fbf3a54d71aa63bcefe376e98cef00034268dab24840'
GO_SHA256_AARCH64='3392582988a273a87ab5043ee1b2c9c17a2c3c00580bf9326c47a2e0aaaeac92'

# pin uv-lock semble lock=semble-requirements.txt input=semble.in
SEMBLE_REQUIREMENTS='semble-requirements.txt'
