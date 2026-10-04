# Choosing Features

Each Feature installs on its own; a few only do their full job alongside another.

| Feature | Adds | Needs |
|---|---|---|
| [`claude-code`](features/claude-code.md) | Claude Code, self-updating, with its login in the `claude-data` volume | — |
| [`gh-config`](features/gh-config.md) | the GitHub CLI's login, kept in the `gh-config` volume | — |
| [`grimoire`](features/grimoire.md) | grimoire's Claude Code plugins, at local scope for each clone | `claude-code`; `node` on `PATH` |
| [`liza`](features/liza.md) | Liza, activated locally for each clone, with ripgrep | — (with `liza-toolchain`, context7 also needs `claude-code`) |
| [`liza-toolchain`](features/liza-toolchain.md) | Liza's agent toolchain: code indexes, semantic search, rtk, context7 | `liza` |
| [`codebase-memory-mcp`](features/codebase-memory-mcp.md) | the codebase-memory-mcp code graph, registered as an MCP server | `claude-code`, to register it |

A Feature never pulls in another: declare each one you want. Each page lists its image
requirements.

## The default set

For [`defaultFeatures`](using.md), the five that make up the agent workbench:
`claude-code`, `gh-config`, `grimoire`, `liza` and `liza-toolchain`.

## codebase-memory-mcp

It's optional next to `liza-toolchain`, whose graph tools cover the same ground; declaring
both registers both. A project that declines the toolchain can declare it to keep a code
graph.
