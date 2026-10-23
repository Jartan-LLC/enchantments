
# Stripe CLI (stripe-cli)

Installs the Stripe CLI from a pinned release.

## Example Usage

```json
"features": {
    "ghcr.io/jartan-llc/enchantments/stripe-cli:1": {}
}
```



## How it works

- **When the image is built,** the pinned Stripe CLI release is installed to `/usr/local/bin/stripe`, after its sha256 is checked.
- **Each time the container starts,** you're told if `stripe` is missing.

## Logging in

`stripe login` keeps its login in `~/.config/stripe`, inside the container, so a rebuild loses it: run `stripe login` again. The Feature can't keep it in a volume: the CLI refuses to write its config through a symlinked folder, and a Feature can't mount a volume at a path in your home.

The CLI uses an API key in `STRIPE_API_KEY` ahead of its login. To keep the key out of the repo, pass it in from your machine's environment: `"containerEnv": { "STRIPE_API_KEY": "${localEnv:STRIPE_API_KEY}" }` in `devcontainer.json`.

## Image requirements

- Debian-based, with bash and `curl`.

## When something fails

The container still starts, and each start says `stripe` is missing. The install happens at image build, so the build log says why; rebuild the container to retry it.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/Jartan-LLC/enchantments/blob/main/src/stripe-cli/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
