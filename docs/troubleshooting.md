# Troubleshooting

## Finding what failed

A Feature's failure never stops the container. What went wrong is printed when the container
next starts. To see failures not printed yet:

```bash
ls ~/.cache/enchantments/*.failures
```

Two failures of the project's own commands change that:

- **Its `postCreateCommand` failed:** the report prints at the following start instead.
- **Its `onCreateCommand` failed:** no Feature finishes its "in the workspace" setup (see
  its page's How it works), and nothing is reported. Fix the command and rebuild the
  container. To avoid a rebuild, run the fixed command in the workspace, then restart the
  container.

A problem a Feature's check finds when the container starts is printed at that start, and at
each start after until it's fixed.

## Retrying a step

Run the failed Feature's hooks as yourself, from the workspace folder, `onCreate.sh` first
where it has one:

```bash
bash /usr/local/share/enchantments/<id>/<hook>.sh
```

Then run `updateContent.sh` for each Feature that depends on it. Each Feature's page lists
what its hooks need.
