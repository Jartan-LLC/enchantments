# Troubleshooting

## Finding what failed

A Feature's failure never stops the container. What went wrong is printed when the container
next starts. To see failures not printed yet:

```bash
ls ~/.cache/enchantments/*.failures
```

Two failures of the project's own commands change that:

- **Its `postCreateCommand` failed:** the report prints at the following start instead.
- **Its `onCreateCommand` failed:** no Feature finishes setting up (grimoire's plugins,
  codebase-memory-mcp's and context7's registration, Liza's activation), and nothing is
  reported. Fix the command and rebuild the container. To avoid a rebuild, run the fixed
  command in the workspace, then restart the container.

## Retrying a step

Run the failed Feature's hooks as yourself, from the workspace folder, `onCreate.sh` first
where it has one:

```bash
bash /usr/local/share/enchantments/<id>/<hook>.sh
```

Then run `updateContent.sh` for each Feature that depends on it. Each Feature's page lists
what its hooks need.
