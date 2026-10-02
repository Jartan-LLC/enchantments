# Troubleshooting

## Where failures are reported

No Feature fails the container: a failing lifecycle step records what went wrong in
`~/.cache/enchantments/<id>.failures`, and the next `postStart` prints it, then renames the
file `<id>.failures.reported`. `ls ~/.cache/enchantments/*.failures` shows what's still
unreported.

- **The project's own `postCreateCommand` failed:** the spec then skips `postStart`, so the
  report prints at the next container start.
- **The project's own `onCreateCommand` failed:** no Feature's configuration runs (grimoire,
  codebase-memory-mcp and context7 registration, Liza activation), and nothing is reported.
  Fix it and rebuild the container. A restart never re-runs `onCreateCommand`, since its
  marker is written before the command runs. Without a rebuild, run the fixed command by
  hand in the workspace, then restart, which runs `updateContentCommand`, or run each
  Feature's staged `updateContent.sh`.

## Retrying

Each Feature stages its hooks as `/usr/local/share/enchantments/<id>/<hook>.sh`. Each is
idempotent and runs as you, from the workspace folder:

```bash
bash /usr/local/share/enchantments/<id>/<hook>.sh
```

Run the failed Feature's hooks, `onCreate.sh` first where it has one, then the
`updateContent.sh` of the Features that depend on it. Each Feature's page says which
steps it has and what its retries need. The Claude Code installer retries once on its
own.
