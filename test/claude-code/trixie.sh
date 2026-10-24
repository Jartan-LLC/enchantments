#!/bin/bash
# shellcheck source-path=SCRIPTDIR
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

hooks=/usr/local/share/enchantments/claude-code
mount=/mnt/enchantments/claude-data

check "claude runs from PATH" claude --version
check "claude belongs to the user" \
  test "$(stat -c %U "$(readlink -f "$HOME/.local/bin/claude")")" = vscode
check ".claude links to claude-data" \
  test "$(readlink -f "$HOME/.claude")" = "$mount"
check ".claude.json links into claude-data" \
  test "$(readlink -f "$HOME/.claude.json")" = "$mount/claude.json"
check "the linked .claude.json exists" \
  test -f "$(readlink -f "$HOME/.claude.json")"
check "claude-data belongs to the user" test "$(stat -c %U "$mount")" = vscode
check "no failures recorded" \
  test -z "$(ls "$HOME"/.cache/enchantments/*.failures* 2>/dev/null)"

# The attach refresh, against a stub claude that lists the plugins in
# $STUB_JSON.
stub=$(mktemp -d)
cat >"$stub/claude" <<'STUB'
#!/bin/bash
if [ "$*" = "plugins list --json" ]; then
  cat "$STUB_JSON"
else
  echo "$*" >>"$STUB_LOG"
fi
STUB
chmod +x "$stub/claude"
refresh() { # plugins-json -> the refresh's claude calls, one per line
  printf '%s' "$1" >"$stub/plugins.json"
  : >"$stub/log"
  STUB_JSON=$stub/plugins.json STUB_LOG=$stub/log PATH="$stub:$PATH" \
    bash "$hooks/postAttach.sh"
  cat "$stub/log"
}

plugins=$(jq -n --arg p "$PWD" '[{id: "a@m1", scope: "user"},
  {id: "b@m2", scope: "local", projectPath: $p},
  {id: "d@m2", scope: "project", projectPath: $p},
  {id: "c@m3", scope: "local", projectPath: "/elsewhere"}]')
expected="plugins marketplace update m1
plugins marketplace update m2
plugins update a@m1 --scope user
plugins update b@m2 --scope local
plugins update d@m2 --scope project"
check "attach refreshes only user-scope plugins and this project's" \
  test "$(refresh "$plugins")" = "$expected"

# A workspace in a subfolder: Claude records a local install under it, settings
# at the root.
root=$(mktemp -d)
git -C "$root" init -q && mkdir "$root/sub"
plugins=$(jq -n --arg w "$root/sub" --arg r "$root" '[
  {id: "b@m2", scope: "local", projectPath: $w},
  {id: "e@m4", scope: "project", projectPath: $r},
  {id: "c@m3", scope: "local", projectPath: "/elsewhere"}]')
expected="plugins marketplace update m2
plugins marketplace update m4
plugins update b@m2 --scope local
plugins update e@m4 --scope project"
check "attach in a subfolder matches the workspace and the repo root" \
  test "$(cd "$root/sub" && refresh "$plugins")" = "$expected"

# VS Code runs the hook with a terminal on stdin: script gives it one. script
# itself reads /dev/null, since a terminal there would stop it under timeout.
check "the attach refresh finishes with a terminal on stdin" \
  timeout 50 script -qec "bash $hooks/postAttach.sh" /dev/null </dev/null

# A second claude on PATH, in a scratch HOME so the real report stays as it was.
probe=$(mktemp -d)
mkdir "$probe/bin" && ln -s /bin/true "$probe/bin/claude"
HOME=$probe PATH="$probe/bin:$PATH" bash "$hooks/postStart.sh" 2>/dev/null
check "a second claude on PATH is reported" grep -q 'more than one claude' \
  "$probe/.cache/enchantments/claude-code.failures.reported"

# The /usr/local/bin link and the install it points to are one claude.
single=$(mktemp -d)
ln -s "$mount" "$single/.claude"
ln -s "$mount/claude.json" "$single/.claude.json"
user_bin=$HOME/.local/bin
PATH="$user_bin:/usr/local/bin:$PATH" HOME=$single \
  bash "$hooks/postStart.sh" 2>/dev/null
check "claude is linked from /usr/local/bin" \
  test "$(readlink -f /usr/local/bin/claude)" \
  = "$(readlink -f "$HOME/.local/bin/claude")"
check "the link and the install count as one claude" \
  test ! -e "$single/.cache/enchantments/claude-code.failures.reported"

# Each start checks what onCreate set up again, unless failures are pending.
unlinked=$(mktemp -d)
HOME=$unlinked bash "$hooks/postStart.sh" 2>/dev/null
check "an unlinked .claude is reported at start" grep -q "/.claude isn't" \
  "$unlinked/.cache/enchantments/claude-code.failures.reported"
check "and an unlinked .claude.json" grep -q "/.claude.json isn't" \
  "$unlinked/.cache/enchantments/claude-code.failures.reported"
pending=$(mktemp -d)
mkdir -p "$pending/.cache/enchantments"
echo earlier >"$pending/.cache/enchantments/claude-code.failures"
HOME=$pending bash "$hooks/postStart.sh" 2>/dev/null
check "a pending failure keeps them quiet" test "$(cat \
  "$pending/.cache/enchantments/claude-code.failures.reported")" = earlier
# A root-owned file in claude-data is taken back at start, or reported where
# sudo can't, here a stub that always fails.
nosudo=$(mktemp -d)
printf '#!/bin/sh\nexit 1\n' >"$nosudo/sudo"
chmod +x "$nosudo/sudo"
sudo -n touch "$mount/.root-owned"
HOME=$single PATH="$nosudo:$PATH" bash "$hooks/postStart.sh" 2>/dev/null
check "without sudo, a root-owned file in claude-data is reported at start" \
  grep -q "can't take back the files" \
  "$single/.cache/enchantments/claude-code.failures.reported"
rm "$single/.cache/enchantments/claude-code.failures.reported"
HOME=$single bash "$hooks/postStart.sh" 2>/dev/null
check "with sudo, it's taken back at start" \
  test "$(stat -c %U "$mount/.root-owned")" = vscode
check "and nothing is reported" \
  test ! -e "$single/.cache/enchantments/claude-code.failures.reported"
rm "$mount/.root-owned"
# Only root's files: another user's stay theirs, and a link is re-owned
# itself, so a dangling one doesn't fail.
sudo -n touch "$mount/.root-owned" "$mount/.other-owned"
sudo -n chown 4242 "$mount/.other-owned"
sudo -n ln -s /nonexistent "$mount/.root-link"
HOME=$single bash "$hooks/postStart.sh" 2>/dev/null
check "root's files are taken back alongside another user's" \
  test "$(stat -c %U "$mount/.root-owned")" = vscode
check "another user's file stays theirs" \
  test "$(stat -c %u "$mount/.other-owned")" = 4242
check "a root-owned link is taken back itself" \
  test "$(stat -c %U "$mount/.root-link")" = vscode
check "and nothing is reported" \
  test ! -e "$single/.cache/enchantments/claude-code.failures.reported"
rm "$mount/.root-owned" "$mount/.root-link"
sudo -n rm "$mount/.other-owned"

# What's in the way of a link is left alone and reported; an empty directory
# isn't in the way.
# shellcheck source=../../src/claude-code/link_home.sh
. "$hooks/link_home.sh"
scratch=$(mktemp -d)
mkdir "$scratch/empty" "$scratch/full" && touch "$scratch/full/kept"
echo '{}' >"$scratch/file"
ln -s "$scratch" "$scratch/other"
check "an empty directory is replaced by the link" \
  link_home "$scratch/empty" "$mount"
check "the link resolves to the target" \
  test "$(readlink -f "$scratch/empty")" = "$mount"
refuses() { ! link_home "$1" "$mount"; }
check "a non-empty directory is refused" refuses "$scratch/full"
check "its contents are kept" test -f "$scratch/full/kept"
check "another link is refused" refuses "$scratch/other"
check "a regular file is refused" refuses "$scratch/file"
is_file() { [ ! -L "$1" ] && [ -f "$1" ]; }
check "the file is kept" is_file "$scratch/file"
check "the target itself is accepted" link_home "$mount" "$mount"

reportResults
