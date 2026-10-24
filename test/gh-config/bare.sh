#!/bin/bash
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

# No gh here, so there's no login to check.
mount=/mnt/enchantments/gh-config
check "gh-config is mounted" mountpoint -q "$mount"
check ".config/gh links to it" test "$(readlink -f ~/.config/gh)" = "$mount"
check "the volume belongs to the user" test "$(stat -c %U "$mount")" = vscode
check "no failures recorded" \
  test -z "$(ls "$HOME"/.cache/enchantments/*.failures* 2>/dev/null)"

# Each start checks what onCreate set up again, unless failures are pending.
hooks=/usr/local/share/enchantments/gh-config
report=.cache/enchantments/gh-config.failures.reported
unlinked=$(mktemp -d)
pending=$(mktemp -d)
mkdir -p "$pending/.cache/enchantments"
echo earlier >"$pending/.cache/enchantments/gh-config.failures"
for home in "$unlinked" "$pending"; do
  HOME=$home bash "$hooks/postStart.sh" 2>/dev/null
done
check "an unlinked .config/gh is reported at start" \
  grep -q "/.config/gh isn't linked" "$unlinked/$report"
check "a pending failure keeps it quiet" \
  test "$(cat "$pending/$report")" = earlier
# A root-owned file is taken back at start, or reported where sudo can't, here
# a stub that always fails.
nosudo=$(mktemp -d)
printf '#!/bin/sh\nexit 1\n' >"$nosudo/sudo"
chmod +x "$nosudo/sudo"
sudo -n touch "$mount/.root-owned"
PATH="$nosudo:$PATH" bash "$hooks/postStart.sh" 2>/dev/null
check "without sudo, a root-owned file in gh-config is reported at start" \
  grep -q "can't take back the files" "$HOME/$report"
rm "$HOME/$report"
bash "$hooks/postStart.sh" 2>/dev/null
check "with sudo, it's taken back at start" \
  test "$(stat -c %U "$mount/.root-owned")" = vscode
check "and nothing is reported" test ! -e "$HOME/$report"
rm "$mount/.root-owned"

no_login_note() {
  local out
  out=$(bash "$hooks/postStart.sh" 2>&1)
  ! grep -q "logged in" <<<"$out"
}
check "without gh, there's no login note" no_login_note

reportResults
