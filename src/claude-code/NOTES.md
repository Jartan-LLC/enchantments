## How it works

- **When the container is created,** Claude Code is installed in your home folder with Anthropic's native installer, and keeps itself up to date. Your login and settings live in the `claude-data` volume, mounted at `/mnt/enchantments/claude-data` and linked from `~/.claude` and `~/.claude.json`, so they survive rebuilds and are shared by every container that uses this Feature.
- **Each time the container starts,** you're warned if more than one `claude` is on `PATH`, such as one installed with npm. Only one of them runs, and it may not be this one.
- **Each time VS Code attaches,** your user plugins and this project's plugins are updated, along with their marketplaces.

## When something else owns the login

Some setups supply the login from outside the container, such as a proxy in `ANTHROPIC_BASE_URL` that adds its own credentials. Claude still authenticates with the login in `claude-data` unless a token is set in its environment: it refreshes that login when it expires or is rejected, and shows `Please run /login` when there is none or the refresh fails. Logging in here to an account the proxy also uses can invalidate the proxy's copy, and a refresh that fails blanks the login for every container that shares the volume.

Set `CLAUDE_CODE_OAUTH_TOKEN` wherever `ANTHROPIC_BASE_URL` is set, such as the `container-env` volume, so the two travel together. When the proxy replaces the credentials, any value works:

```bash
printf '%s' 'proxy' >/mnt/enchantments/container-env/CLAUDE_CODE_OAUTH_TOKEN
```

Claude then uses that token and never refreshes or blanks the login in `claude-data`, so no container needs to log in. In exchange, claude.ai connectors don't load, since Claude fetches them from Anthropic directly with that token, and Claude shows `Claude API` rather than your plan.

While `ANTHROPIC_BASE_URL` points anywhere but `api.anthropic.com` and none of `CLAUDE_CODE_OAUTH_TOKEN`, `ANTHROPIC_AUTH_TOKEN` or `ANTHROPIC_API_KEY` is set, a warning is printed each time the container starts.

## Image requirements

- Debian-based, with `curl` and `jq`.

## When something fails

The container still starts, and what went wrong is printed the next time it starts. To retry a step, run it from the workspace folder: `bash /usr/local/share/enchantments/claude-code/<hook>.sh`.
