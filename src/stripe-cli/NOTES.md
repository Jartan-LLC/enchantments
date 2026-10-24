## How it works

- **When the image is built,** the pinned Stripe CLI release is installed to `/usr/local/bin/stripe`, after its sha256 is checked.
- **Each time the container starts,** you're told if `stripe` is missing.

To declare it for every container you open, see `https://github.com/Jartan-LLC/enchantments#declaring-a-feature`.

## Logging in

`stripe login` keeps its login in `~/.config/stripe`, inside the container, so a rebuild loses it: run `stripe login` again. The Feature can't keep it in a volume: the CLI refuses to write its config through a symlinked folder, and a Feature can't mount a volume at a path in your home.

The CLI uses an API key in `STRIPE_API_KEY` ahead of its login. To keep the key out of every repo, set it per device with the `container-env` Feature: `https://github.com/Jartan-LLC/enchantments/tree/main/src/container-env`. Without it, pass the key in from your machine's environment: `"containerEnv": { "STRIPE_API_KEY": "${localEnv:STRIPE_API_KEY}" }` in `devcontainer.json`.

## Image requirements

- Debian-based, with `curl`.

## When something fails

The container still starts, and each start says `stripe` is missing. The install happens at image build, so the build log says why; rebuild the container to retry it.

## Removal

The Feature leaves nothing behind: the CLI and its login go with the container. A `STRIPE_API_KEY` set with the `container-env` Feature stays in its volume.
