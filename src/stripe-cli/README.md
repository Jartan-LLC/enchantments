
# Stripe CLI (stripe-cli)

Installs the Stripe CLI from a pinned release, and keeps its login in the stripe-config volume, so it survives rebuilds and is shared by every container that mounts it.

## Example Usage

```json
"features": {
    "ghcr.io/jartan-llc/enchantments/stripe-cli:1": {}
}
```



## How it works

- **When the image is built:** the pinned Stripe CLI release is installed to `/usr/local/bin/stripe`, after its sha256 is checked.
- **When the container is created:** `~/.config/stripe` is linked to the `stripe-config` volume, mounted at `/mnt/enchantments/stripe-config`.
- **Each time the container starts:** you're told if `stripe` is missing, and what the create-time step recorded.

Log in once with `stripe login`. The login lives in the `stripe-config` volume, so it survives rebuilds and is shared by every container that uses this Feature. When it expires, run `stripe login` again.

## Using an API key instead

The CLI reads `STRIPE_API_KEY` ahead of its login, wherever the container's environment sets it, such as `containerEnv` in `devcontainer.json`.

## Security

The CLI keeps its login in a plain-text file in the volume, since a container has no keyring. Every container on this Docker host that mounts `stripe-config` can read it. See the trust boundary guide: `https://github.com/Jartan-LLC/enchantments/blob/main/docs/trust-boundary.md`.

## Removal

Run `stripe logout --all`, then remove the Feature. The volume stays: `docker volume rm stripe-config` deletes it.

## Image requirements

- Debian-based, with bash and `curl`.

## When something fails

The container still starts, and what went wrong is printed the next time it starts. To retry a step, run it from the workspace folder: `bash /usr/local/share/enchantments/stripe-cli/<hook>.sh`. A failed download of `stripe` happened at image build: rebuild the container to retry it.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/Jartan-LLC/enchantments/blob/main/src/stripe-cli/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
