# shellcheck shell=bash disable=SC2034
# This Feature's pins: one single-quoted NAME='value' per line under its
# "# pin <kind> <tool>" header, so tooling can parse the file without running
# it. The npm tools are pinned by npm/package-lock.json, which Dependabot
# updates.

# pin asset ast-grep repo=ast-grep/ast-grep
AST_GREP_TAG='0.51.0'
AST_GREP_ASSET_X86_64='app-x86_64-unknown-linux-gnu.zip'
AST_GREP_SHA256_X86_64='a7eead5552d3a8daad70f5d50d935da44bd0c138e946b5b0a96b1d38169fa639'
AST_GREP_ASSET_AARCH64='app-aarch64-unknown-linux-gnu.zip'
AST_GREP_SHA256_AARCH64='73af0ebe5958acee012754a5b2826a186580ef83333092408a7a01096fc30b8b'

# pin asset yq repo=mikefarah/yq
YQ_TAG='v4.54.1'
YQ_ASSET_X86_64='yq_linux_amd64'
YQ_SHA256_X86_64='8e34fc298390875de416e6a4afcb8cabeceb25d9aa8506c1a2f9353cf702ea5f'
YQ_ASSET_AARCH64='yq_linux_arm64'
YQ_SHA256_AARCH64='189088da0c6429ec5178dfaab1a114805f6cab0b61b165ab236efedf1d57a71b'

# pin asset rtk repo=rtk-ai/rtk
RTK_TAG='v1.1.0'
RTK_ASSET_X86_64='rtk-x86_64-unknown-linux-musl.tar.gz'
RTK_SHA256_X86_64='9454ad1b9489daa57ab0a9f4ebe2faaf4dc82b8a0f26c9e5135151abd7c9378d'
RTK_ASSET_AARCH64='rtk-aarch64-unknown-linux-gnu.tar.gz'
RTK_SHA256_AARCH64='a5c00c3ab0129884bcb757d348afc1a650efa0f4f0769da97c341f28f89719ed'

# pin asset mdq repo=yshavit/mdq
MDQ_TAG='v0.10.0'
MDQ_ASSET_X86_64='mdq-linux-x64-musl.tar.gz'
MDQ_SHA256_X86_64='673ed676382f54a21e4381d845236c776b2b71ed8dc1cc3e92cf6d66a39edb07'

# pin asset uv repo=astral-sh/uv
UV_TAG='0.13.6'
UV_ASSET_X86_64='uv-x86_64-unknown-linux-musl.tar.gz'
UV_SHA256_X86_64='5d61f26b6c7213779eda90edc6971ea6b0b796bfb8d49a574c8ad69b59838548'
UV_ASSET_AARCH64='uv-aarch64-unknown-linux-musl.tar.gz'
UV_SHA256_AARCH64='819692e404d23e5aae6bc44c0e260f1f5492fd1910ab4693b2c650f926dbe800'

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
NODE_VERSION='v26.13.0'
NODE_SHA256_X86_64='5848553868b402d3fabb5b09270649977780a390f832155721025a08b5104455'
NODE_SHA256_AARCH64='439e9c438acdf6a6ffe47418da709153d66c4bed812e30a473faacb107dd2791'

# pin go go
GO_VERSION='1.27.3'
GO_SHA256_X86_64='65efbc80fdc1fa2cd2631cad5b481777a68e8725f34e89f50fc6ac714e379b40'
GO_SHA256_AARCH64='a06e99309dbcbdca1a8ccd2282c3ee146e55930886e26b4f1193269587165f49'

# pin uv-lock semble lock=semble-requirements.txt input=semble.in
SEMBLE_REQUIREMENTS='semble-requirements.txt'
