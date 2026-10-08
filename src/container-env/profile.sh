# shellcheck shell=sh
# install.sh copies this to /etc/profile.d/container-env.sh. Login shells
# source it, and VS Code takes their environment through userEnvProbe.
# postStart reports problems, so every shell doesn't.
if command -v bash >/dev/null 2>&1 \
  && [ -f /usr/local/share/enchantments/container-env/load.sh ]; then
  eval "$(bash /usr/local/share/enchantments/container-env/load.sh \
    2>/dev/null)"
fi
