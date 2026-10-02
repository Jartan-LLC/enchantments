# What persists

A rebuild replaces the container. These volumes outlive it:

| Volume | Holds | Shared by |
|---|---|---|
| `claude-data` | Claude Code's login and `~/.claude`: settings, plugins, MCP entries, and each clone's local-scope plugins | every container with `claude-code` |
| `gh-config` | the GitHub CLI's login | every container with `gh-config` |
| `liza-<devcontainerId>` | Liza and its toolchain | one opened config |

## The Liza volumes

Each opened config gets its own `liza-<devcontainerId>` volume, about 0.5 GB, filled when
its container is first created. It stays behind when the clone moves or is deleted. To
prune the ones no container uses:

```bash
docker volume ls -q --filter dangling=true --filter name='(^|_)liza-' | xargs -r docker volume rm
```

## Docker Compose

Compose prefixes each Feature volume with the project name (`<project>_claude-data` and so
on), so a Compose config's login and gh auth aren't shared with other containers.
