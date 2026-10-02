# Using Features

Declare a Feature in either place:

- **For a project:** under `features` in its `devcontainer.json`, for everyone who opens it.
- **For yourself, in every container:** in VS Code's `dev.containers.defaultFeatures`
  setting. Read [the trust boundary](trust-boundary.md) first.

```json
{
  "ghcr.io/jartan-llc/enchantments/claude-code:1": {}
}
```

Use exactly `ghcr.io/jartan-llc/enchantments/<id>:1`, in both places. Declared with another
version, a digest or other options, a Feature can install twice.

## Removing a Feature

Follow the removal steps on its page first: some Features leave registrations or volumes
behind. Then remove it from the project's `devcontainer.json` and from `defaultFeatures`,
which otherwise brings it back at the next rebuild.
