# enchantments

Dev container Features for Jartan LLC's projects, each one installable on its own.

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

```{toctree}
:maxdepth: 1
:caption: Features

features/claude-code
features/codebase-memory-mcp
features/gh-config
features/grimoire
```

```{toctree}
:maxdepth: 2
:caption: Maintenance

scaffold
```
