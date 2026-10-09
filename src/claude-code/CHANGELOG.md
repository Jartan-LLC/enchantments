## 1.1.0

- Warns at start when `ANTHROPIC_BASE_URL` points away from Anthropic but no token is set in the environment, so Claude would use, and could blank, the shared login. The page explains setting `CLAUDE_CODE_OAUTH_TOKEN` when something else owns the login.

## 1.0.1

- Claude runs without the hook's terminal, so the attach refresh no longer hangs.

## 1.0.0

- First release.
