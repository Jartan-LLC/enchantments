## How it works

- **When the container is created,** every tool below is installed at its pinned version into the `liza` Feature's volume, and `/mnt/enchantments/liza/bin` goes on `PATH`. Node and uv stay in the volume, off `PATH`; Go is fetched only to build, then deleted. A rebuild reinstalls only what changed.
- **Then, in the workspace,** the `liza` Feature turns the toolchain on: Liza's `LIZA_ENABLE_*` gates go in `~/.liza/toolchain/env.sh`, which your login shell's startup files source, and, with the `claude-code` Feature, context7 is registered with Claude Code for this clone.
- **Without `liza`,** it installs nothing, and says so.

## Tools

| Tool | Installed from |
|---|---|
| ast-grep, yq, rtk | release binary + sha256 |
| mdq (x86_64 only) | release binary + sha256 |
| stacklit, scip-search, functional-clusters, mdtoc, bash-policy | source at a pinned commit, built with a pinned Go |
| scip-python, scip-typescript, context7 MCP | `npm/package-lock.json`, run by a pinned Node |
| semble | `semble-requirements.txt` (hash-locked), in a venv a pinned uv builds; its model by revision and sha256 |

## Known limitations

- scip-python doesn't see packages installed in a uv virtual environment, which has no `pip`.
- Liza won't activate a clone that has its own `post-checkout`, `post-commit`, `post-merge` or `post-rewrite` git hook; git-lfs, husky and lefthook install such hooks. Activation names the hook.
- Where rtk can't run (aarch64 with glibc older than 2.39), it's removed, left out of `~/.liza/AGENT_TOOLS.md`, and reported at each create.

## Removal

1. While both Features are still declared, in each clone, run `liza-deactivate --tools`, then `liza-deactivate`.
2. Remove the entry.
3. To also remove the toolchain's files, remove the container, then the volume: `docker volume rm liza-<devcontainerId>`. Docker won't remove a volume that any container, even a stopped one, still uses. The rebuild reinstalls Liza into a fresh one.
4. Rebuild: activation runs again without the toolchain.

## Image requirements

- Debian-based, with `bash`, `curl`, `jq`, `git` and `unzip`.
- On aarch64, glibc 2.39 or later (Debian trixie or later), for rtk.
- `pip` on `PATH`, for Python's code index.

## When something fails

The container still starts, and what went wrong is printed the next time it starts. To retry, run it from the workspace folder: `bash /usr/local/share/enchantments/liza-toolchain/onCreate.sh`. A failed tool is retried on the next create.

A `liza toolchain configure` failure after a Liza release means `liza` and `liza-toolchain` are declared differently: declare both in the project's config, or both only through `defaultFeatures`.
