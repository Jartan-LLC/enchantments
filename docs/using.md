# Using Features

There are two places to declare a Feature, and both take the same key.

- **In a project,** under `features` in its `devcontainer.json`. It applies to everyone who
  opens that project.
- **For you, in every container,** under VS Code's `dev.containers.defaultFeatures` setting.
  Read [the trust boundary](trust-boundary.md) before setting it.

```json
{
  "ghcr.io/jartan-llc/enchantments/claude-code:1": {}
}
```

## Use the exact key

Write `ghcr.io/jartan-llc/enchantments/<id>:1` in both places. The CLI merges two
different keys only while they resolve to the same digest with the same options:

- a full version or a digest runs the Feature once today, then twice once `:1` moves to a
  newer release, or at once if the options differ;
- `:2` always runs it twice.

## Declining a Feature

A Feature in `defaultFeatures` comes back on every rebuild, so removing a project's entry
doesn't decline it for you; remove it from the setting too. Before removing a Feature,
follow the removal steps on its page: some leave registrations or volumes behind.
