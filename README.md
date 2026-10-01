# enchantments

[![CI](https://github.com/Jartan-LLC/enchantments/actions/workflows/ci.yml/badge.svg)](https://github.com/Jartan-LLC/enchantments/actions/workflows/ci.yml)

Dev container Features for Jartan LLC's projects, each one installable on its own.

## Features

| Feature | What it does |
|---|---|
| [`claude-code`](src/claude-code/README.md) | Installs Claude Code, which updates itself, and keeps its login in the `claude-data` volume. |
| [`codebase-memory-mcp`](src/codebase-memory-mcp/README.md) | Installs the codebase-memory-mcp code graph and registers it as an MCP server. |
| [`gh-config`](src/gh-config/README.md) | Keeps the GitHub CLI's login in the `gh-config` volume. |
| [`grimoire`](src/grimoire/README.md) | Installs plugins from the grimoire Claude Code marketplace. |

<!-- declare:start -->
None is published yet. Once they are, declare one in a project's `devcontainer.json`, or
for every container in VS Code's `dev.containers.defaultFeatures`:

```json
{
  "features": {
    "ghcr.io/jartan-llc/enchantments/claude-code:1": {}
  }
}
```

Use that exact key, `:1` included, in both places, so a Feature declared twice runs once.
<!-- declare:end -->

## Contributing

Setup and the checks a change must pass: [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE).
