
# Liza toolchain (liza-toolchain)

Liza's agent toolchain, every tool pinned and verified, installed into the liza Feature's volume with private Go, Node and uv that stay off PATH.

## Example Usage

```json
"features": {
    "ghcr.io/jartan-llc/enchantments/liza-toolchain:1": {}
}
```



## How it works

- **When the container is created,** every tool below is installed at its pinned version into the `liza` Feature's volume, and `/mnt/enchantments/liza/bin` goes on `PATH`. Go, Node and uv are private: they stay in the volume, off `PATH`. A rebuild reinstalls only what changed.
- **Then, in the workspace,** the `liza` Feature turns the toolchain on: Liza's `LIZA_ENABLE_*` gates go in `~/.liza/toolchain/env.sh`, which `~/.bashrc` and `~/.profile` source, and context7 is registered with Claude Code for this clone.
- **Declare it the same way as `liza`:** both in the project's config, or both only through `defaultFeatures`. A project's lockfile pins only the Features it declares, so after a Liza release the two can differ until the lockfile moves, which shows as a recorded `liza toolchain configure` failure.
- **Without `liza`,** it installs nothing, and says so.

## Tools

| Tool | Installed from | Notes |
|---|---|---|
| ast-grep, yq, rtk | release binary + sha256 | rtk's arm64 build needs glibc 2.39 or later |
| mdq | release binary + sha256 | x86_64 only: mdq publishes no arm64 Linux build |
| stacklit, scip-search, functional-clusters, mdtoc, bash-policy | source at a pinned commit, built with a pinned Go | no upstream release binaries |
| scip-python, scip-typescript, context7 MCP | `npm/package-lock.json`, run by a pinned Node | context7 registered at local scope |
| semble | `semble-requirements.txt` (hash-locked), in a venv a pinned uv builds | its model is pinned by revision and sha256, and never downloads at runtime |

- **`codebase-memory-mcp` is optional alongside it:** the toolchain's graph tools cover the same ground. Declaring both registers both.
- **scip-python** indexes project code. It sees third-party packages only through `pip`, which uv virtual environments don't include.
- **rtk on older glibc:** where rtk can't run, it's removed and reported at each start, and `~/.liza/AGENT_TOOLS.md` still describes it.

## Removal

While both Features are still declared, run `liza-deactivate --tools` and then `liza-deactivate` in each clone: plain deactivation is what removes the rtk and bash-policy hooks from `.claude/settings.local.json`. Then remove the entry, or swap it for `codebase-memory-mcp` if you want a code graph, and rebuild: activation runs again without the toolchain's gates or rtk.

## Image requirements

- Debian-based, with `bash`, `curl`, `jq`, `git` and `unzip`.
- On aarch64, glibc 2.39 or later (Debian trixie or later) for rtk.

## When something fails

The container still starts, and what went wrong is printed the next time it starts. To retry, run it from the workspace folder: `bash /usr/local/share/enchantments/liza-toolchain/onCreate.sh`. A failed tool is retried on the next create.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/Jartan-LLC/enchantments/blob/main/src/liza-toolchain/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
