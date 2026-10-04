
# Liza toolchain (liza-toolchain)

Liza's agent toolchain, every tool pinned and verified, installed into the liza Feature's volume.

## Example Usage

```json
"features": {
    "ghcr.io/jartan-llc/enchantments/liza-toolchain:1": {}
}
```



## How it works

- **When the container is created,** every tool below is installed at its pinned version into the `liza` Feature's volume, and `/mnt/enchantments/liza/bin` goes on `PATH`. Node and uv stay in the volume, off `PATH`; Go is fetched only to build, then deleted. A rebuild reinstalls only what changed.
- **Then, in the workspace,** the `liza` Feature turns the toolchain on: Liza's `LIZA_ENABLE_*` gates go in `~/.liza/toolchain/env.sh`, which your login shell's startup files source, and, with the `claude-code` Feature, context7 is registered with Claude Code for this clone.
- **Without `liza`,** it installs nothing, and says so.

## Tools

Release binaries, each checked against its sha256:

- **ast-grep**: structural code search and rewrite with syntax-tree patterns, for when
  syntax matters more than names.
- **yq**: jq-style querying and editing for YAML, JSON, XML and TOML.
- **rtk**: a proxy that compresses command output before it reaches the agent, to save
  tokens. Not on aarch64 with glibc older than 2.39.
- **mdq**: jq for Markdown: selects sections, lists and tables. x86_64 only.

Built from the `liza-mas` sources at a pinned commit, with a pinned Go:

- **stacklit**: indexes a repo with tree-sitter into a compact `stacklit.json` (modules,
  dependencies, exports, hints), queried with subcommands such as `find-module` and
  `get-hot-files`.
- **scip-search**: queries SCIP indexes for symbols, references, implementations,
  callers, callees and impact, in place of grepping and reading files.
- **functional-clusters**: groups code into advisory functional clusters from scip-search
  and Stacklit exports; `explain` shows why a symbol is in its cluster.
- **mdtoc**: prints each Markdown heading with its line range and an mdq selector.
- **bash-policy**: splits an agent's Bash commands into single commands and applies allow
  and deny rules to each, finer than Claude Code's `Bash(...)` rules. It also covers Codex
  and Cursor, and can audit in dry-run mode.

From `npm/package-lock.json`, run by a pinned Node kept off `PATH`:

- **scip-python, scip-typescript**: Sourcegraph's indexers, which write the SCIP indexes
  scip-search reads.
- **context7 MCP**: an MCP server that gives the agent current library docs; registered
  with Claude Code when the `claude-code` Feature is present.

In a venv that a pinned uv builds from the hash-locked `semble-requirements.txt`:

- **semble**: code search for agents that returns just the snippets they need, mixing
  static embeddings from the potion-code-16M model with BM25 keyword matching. The model
  is fetched at a pinned revision and sha256, so semble never downloads it at run time.

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

The container still starts, and what went wrong is printed the next time it starts. To retry, run from the workspace folder `bash /usr/local/share/enchantments/liza-toolchain/onCreate.sh`, then `bash /usr/local/share/enchantments/liza/updateContent.sh`, which puts a reinstalled tool to use. A failed tool is retried on the next create.

A `liza toolchain configure` failure after a Liza release means `liza` and `liza-toolchain` are declared differently: declare both in the project's config, or both only through `defaultFeatures`.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/Jartan-LLC/enchantments/blob/main/src/liza-toolchain/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
