#!/bin/bash
set -e
source dev-container-features-test-lib

# Any release older than the current one; the installer's version argument installs it.
old=2.1.240
curl -fsSL https://claude.ai/install.sh | bash -s "$old"
check "the older release is installed" bash -c "claude --version | grep -q '^$old '"
claude update || true
check "claude update moved past it" bash -c "! claude --version | grep -q '^$old '"
in_user_share() {
    case "$(readlink -f "$HOME/.local/bin/claude")" in "$HOME"/.local/share/claude/*) return 0 ;; esac
    return 1
}
check "the binary stays in the user's home" in_user_share
check "the binary belongs to the user" test "$(stat -c %U "$(readlink -f "$HOME/.local/bin/claude")")" = vscode

reportResults
