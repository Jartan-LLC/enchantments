# What persists

A rebuild replaces the container. These volumes outlive it:

| Volume | Holds | Shared by |
|---|---|---|
| `claude-data` | Claude Code's login and `~/.claude`: settings, plugins, MCP entries, and each clone's local-scope plugins | every container with `claude-code` |
| `container-env` | the variables `container-env` exports | every container with `container-env` |
| `gh-config` | the GitHub CLI's login | every container with `gh-config` |
| `liza-<devcontainerId>` | Liza and its toolchain | one opened config |

## Sharing a volume

Containers that share a volume must run as one uid: Claude Code and gh keep their logins
readable by their owner alone. On a Linux host, the dev container CLI gives the container's
user your uid, unless `updateRemoteUserUID` is `false` or another user in the image already
has that uid; elsewhere, the user keeps the image's uid.

A container running as another uid leaves the other user's files alone, and warns that the
volume holds them. Run it as the same uid as the others, or take the volume for this
container with the command in the warning, which locks out the containers running as the
other uid. A volume that's still empty is taken by the next container created on it,
whatever uid owns it; a container of another uid already using it then warns at its next
start. A container running as root can use any volume; the others take back what it leaves
at their next start or rebuild, once the volume holds no other uid's files. [The trust
boundary](trust-boundary.md) covers what a root container can reach.

## The Liza volumes

Each opened config gets its own `liza-<devcontainerId>` volume, about 0.5 GB, filled when
its container is first created. If it holds files of another uid, such as your old one
after a rebuild under a new uid, creating the container warns and gives the command to
take it. It stays behind when the clone moves or is deleted. To prune the ones no
container uses:

```bash
docker volume ls -q --filter dangling=true --filter name='(^|_)liza-' | xargs -r docker volume rm
```

## Docker Compose

Compose prefixes each Feature volume with the project name (`<project>_claude-data` and so
on), so a Compose config's login, gh auth and `container-env` values aren't shared with
other containers.
