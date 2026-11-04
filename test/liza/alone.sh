#!/bin/bash
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

# The CLI copies the test files into the workspace after create.
printf '%s\n' '/*.sh' /scenarios.json /dev-container-features-test-lib \
  >>.git/info/exclude

activated() {
  [ "$(readlink -f CLAUDE.local.md)" = "$(readlink -f ~/.liza/CORE.md)" ] \
    && test -f "$(git rev-parse --git-path liza)/activation.json"
}
no_rtk_or_bash_policy_hook() {
  [ -f .claude/settings.local.json ] \
    && ! jq -r '.hooks[]?[]?.hooks[]?.command' .claude/settings.local.json \
    | grep -Eq 'bin/(rtk|bash-policy) '
}
reports=~/.cache/enchantments
check "Liza is activated for the clone" activated
check "git status is clean" test -z "$(git status --porcelain)"
check "AGENT_TOOLS.md is the minimal one" \
  grep -q "liza-toolchain is absent" ~/.liza/AGENT_TOOLS.md
check "no rtk or bash-policy hook" no_rtk_or_bash_policy_hook
check "no failures recorded" \
  test -z "$(ls "$reports"/*.failures* 2>/dev/null)"
# The onCreateCommand registered context7 before activation, and activation's
# cleanup removes only a registration it made.
check "a context7 Liza didn't register survives" \
  bash -c 'claude mcp get context7 >/dev/null'
# shellcheck disable=SC2016 # a jq program
check "and keeps its command" \
  jq -e --arg p "$PWD" '.projects[$p].mcpServers.context7.command == "true"' \
  ~/.claude.json

# The image has no pre-commit, so the Feature's is on PATH, and uv linked no
# Python into ~/.local/bin while installing it.
pre_commit=/mnt/enchantments/liza/lib/pre-commit
check "pre-commit runs from PATH" pre-commit --version
check "and is the Feature's" \
  test "$(command -v pre-commit)" = "$pre_commit/bin/pre-commit"
check "no Python in ~/.local/bin" \
  test -z "$(find ~/.local/bin -name 'python*' -print -quit)"

# A pre-commit of yours first on PATH is used: none is installed.
mine=$(mktemp -d)
printf '#!/bin/sh\necho mine\n' >"$mine/pre-commit"
chmod +x "$mine/pre-commit"
mv "$pre_commit" "$pre_commit.kept"
HOME=$mine PATH=$mine:$PATH \
  bash /usr/local/share/enchantments/liza/onCreate.sh 2>/dev/null
check "a pre-commit of yours means none is installed" test ! -e "$pre_commit"
check "and nothing is reported" \
  test ! -e "$mine/.cache/enchantments/liza.failures"
mv "$pre_commit.kept" "$pre_commit"
rm -rf "$mine"

# On a rebuild PATH finds the Feature's own pre-commit: it is kept while its
# pins match and reinstalled when they change.
rebuild=$(mktemp -d)
pins=$(cat "$pre_commit/pins")
touch -d @0 "$pre_commit/pins"
HOME=$rebuild bash /usr/local/share/enchantments/liza/onCreate.sh 2>/dev/null
check "a rebuild keeps a current pre-commit" \
  test "$(stat -c %Y "$pre_commit/pins")" = 0
echo stale >"$pre_commit/pins"
HOME=$rebuild bash /usr/local/share/enchantments/liza/onCreate.sh 2>/dev/null
check "and reinstalls one whose pins changed" \
  test "$(cat "$pre_commit/pins")" = "$pins"
check "which runs" "$pre_commit/bin/pre-commit" --version
check "and nothing is reported" \
  test ! -e "$rebuild/.cache/enchantments/liza.failures"
rm -rf "$rebuild"

# A failed rebuild puts the old install back, even one a run cut short left
# aside: here a run stopped mid-build, and its retry's hashes don't match.
broken=$(mktemp -d)
cp -R /usr/local/share/enchantments/liza "$broken/hooks"
sed -i "s/sha256:[0-9a-f]\{64\}/sha256:$(printf '%064d' 0)/" \
  "$broken/hooks/pre-commit-requirements.txt"
mv "$pre_commit" "$pre_commit.old"
mkdir -p "$pre_commit/venv"
HOME=$broken bash "$broken/hooks/onCreate.sh" 2>/dev/null
check "a failed rebuild is reported" \
  grep -q "install of pre-commit failed" \
  "$broken/.cache/enchantments/liza.failures"
check "and puts the old pre-commit back" \
  test "$(cat "$pre_commit/pins")" = "$pins"
check "which runs" "$pre_commit/bin/pre-commit" --version
check "with nothing left aside" test ! -e "$pre_commit.old"
rm -rf "$broken"

# What a finished build left aside is stale: deleted even when nothing needs
# installing, and never put back over the install.
stale=$(mktemp -d)
inode=$(stat -c %i "$pre_commit")
mkdir -p "$pre_commit.old/venv"
HOME=$stale bash /usr/local/share/enchantments/liza/onCreate.sh 2>/dev/null
check "a stale copy left aside is deleted" test ! -e "$pre_commit.old"
check "and the install kept" test "$(stat -c %i "$pre_commit")" = "$inode"
check "and nothing is reported" \
  test ! -e "$stale/.cache/enchantments/liza.failures"
rm -rf "$stale"

# A rebuild that fails before it fetches uv leaves the install untouched.
no_uv=$(mktemp -d)
cp -R /usr/local/share/enchantments/liza "$no_uv/hooks"
sed -i "s/^\(PRE_COMMIT_UV_SHA256_[A-Z0-9_]*=\).*/\1'$(printf '%064d' 0)'/" \
  "$no_uv/hooks/pins.sh"
echo stale >"$pre_commit/pins"
HOME=$no_uv bash "$no_uv/hooks/onCreate.sh" 2>/dev/null
check "a rebuild whose uv fails is reported" \
  grep -q "install of pre-commit failed" \
  "$no_uv/.cache/enchantments/liza.failures"
check "and leaves the install untouched" \
  test "$(stat -c %i "$pre_commit")" = "$inode" \
  -a "$(cat "$pre_commit/pins")" = stale
echo "$pins" >"$pre_commit/pins"
rm -rf "$no_uv"

# A ~/.liza of your own is reported, never replaced.
own_home=$(mktemp -d)
mkdir -p "$own_home/.liza/mine"
HOME=$own_home bash /usr/local/share/enchantments/liza/onCreate.sh 2>/dev/null
check "a ~/.liza of your own is reported" \
  grep -q "in the way" "$own_home/.cache/enchantments/liza.failures"
check "and kept" test -d "$own_home/.liza/mine" -a ! -L "$own_home/.liza"
rm -rf "$own_home"

# The commands on PATH, by name.
check "liza-deactivate runs" liza-deactivate
check "liza-deactivate unlinks the contract" \
  test ! -e CLAUDE.local.md -a ! -L CLAUDE.local.md
check "liza-deactivate drops the record" \
  test ! -e "$(git rev-parse --git-path liza)/activation.json"
check "git status is clean after liza-deactivate" \
  test -z "$(git status --porcelain)"
check "liza-activate runs" liza-activate
check "liza-activate links the contract again" activated
check "liza-activate records nothing" test ! -e "$reports/liza.failures"

# Each start checks what onCreate set up again, unless failures are pending.
hooks=/usr/local/share/enchantments/liza
mv ~/.local/bin/rg ~/.local/bin/rg.kept
ln -s /nonexistent ~/.local/bin/rg
bash "$hooks/postStart.sh" 2>/dev/null
check "an rg that doesn't run is reported at start" \
  grep -q "rg doesn't run" "$reports/liza.failures.reported"
rm ~/.local/bin/rg
bash "$hooks/postStart.sh" 2>/dev/null
check "a missing rg is reported at start" \
  grep -q "rg is missing" "$reports/liza.failures.reported"
mv ~/.local/bin/rg.kept ~/.local/bin/rg
report=.cache/enchantments/liza.failures.reported
in_way=$(mktemp -d)
missing=$(mktemp -d)
pending=$(mktemp -d)
mkdir "$in_way/.liza"
mkdir -p "$pending/.cache/enchantments"
echo earlier >"$pending/.cache/enchantments/liza.failures"
for home in "$in_way" "$missing" "$pending"; do
  HOME=$home bash "$hooks/postStart.sh" 2>/dev/null
done
check "a ~/.liza in the way is reported at start" \
  grep -q "isn't the liza volume" "$in_way/$report"
check "a missing ~/.liza is reported at start" \
  grep -q ".liza is missing" "$missing/$report"
check "a pending failure keeps them quiet" \
  test "$(cat "$pending/$report")" = earlier

reportResults
