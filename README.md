# enchantments

[![CI](https://github.com/Jartan-LLC/enchantments/actions/workflows/ci.yml/badge.svg)](https://github.com/Jartan-LLC/enchantments/actions/workflows/ci.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/Jartan-LLC/enchantments/badge)](https://scorecard.dev/viewer/?uri=github.com/Jartan-LLC/enchantments)

[Dev container Features](https://containers.dev/features) that set up Claude
Code and agent tools on Debian-based images.

## Features

| Feature | What you get |
|---|---|
| [`claude-code`](src/claude-code/README.md) | Claude Code, self-updating, with its login kept across rebuilds |
| [`codebase-memory-mcp`](src/codebase-memory-mcp/README.md) | a code graph Claude Code can query |
| [`container-env`](src/container-env/README.md) | per-device environment variables, kept out of every repo |
| [`gh-config`](src/gh-config/README.md) | the GitHub CLI's login, kept across rebuilds (`gh` not included) |
| [`grimoire`](src/grimoire/README.md) | Claude Code plugins from the [grimoire](https://github.com/Jartan-LLC/grimoire) marketplace |
| [`liza`](src/liza/README.md) | [Liza](https://github.com/liza-mas/liza): rules and a multi-agent workflow for coding agents, with ripgrep |
| [`liza-toolchain`](src/liza-toolchain/README.md) | Liza's agent tools, such as code indexes and code search |

## Declaring a Feature

<!-- declare:start -->
Declare each Feature you want under `features` in a project's `devcontainer.json`:

```json
{
  "features": {
    "ghcr.io/jartan-llc/enchantments/claude-code:1": {}
  }
}
```

A Feature never installs another; [Choosing Features](docs/choosing.md) lists the ones
that need one. To declare one for every container you open, read the
[trust boundary guide](docs/trust-boundary.md) first, then add the same key to VS Code's
`dev.containers.defaultFeatures` (no `features` wrapper). Use that exact key, `:1`
included, in both places, so a Feature declared twice runs once.
<!-- declare:end -->

## Documentation

[Choosing Features](docs/choosing.md) · [Using and removing](docs/using.md) ·
[What persists](docs/persistence.md) · [Trust boundary](docs/trust-boundary.md) ·
[Troubleshooting](docs/troubleshooting.md) · [Contributing](CONTRIBUTING.md)

## License

[MIT](LICENSE).
