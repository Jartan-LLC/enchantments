## How it works

- **When the image is built:** the pinned Stripe CLI release is installed to `/usr/local/bin/stripe`, after its sha256 is checked.
- **Each time the container starts:** you're told if `stripe` is missing.

## Logging in

`stripe login` keeps its login in `~/.config/stripe`, inside the container, so a rebuild loses it: run `stripe login` again. The Feature can't keep it in a volume: the CLI refuses to write its config through a symlinked folder, and a Feature can't mount a volume at a path in your home.

The CLI reads `STRIPE_API_KEY` ahead of its login, wherever the container's environment sets it, such as `containerEnv` in `devcontainer.json`.

## Removal

Remove the Feature.

## Image requirements

- Debian-based, with bash and `curl`.

## When something fails

The container still starts, and the next start says `stripe` is missing. The download happens at image build: rebuild the container to retry it.
