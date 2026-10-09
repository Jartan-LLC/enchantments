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
user_bin=$HOME/.local/bin
PATH="$user_bin:/usr/local/bin:$PATH" HOME=$single \
  bash "$hooks/postStart.sh" 2>/dev/null
check "claude is linked from /usr/local/bin" \
  test "$(readlink -f /usr/local/bin/claude)" \
  = "$(readlink -f "$HOME/.local/bin/claude")"
check "the link and the install count as one claude" \
  test ! -e "$single/.cache/enchantments/claude-code.failures.reported"

# A base URL Claude would reach with the shared login, in scratch HOMEs, with
# only the given auth variables set.
start_report() { # VAR=value... -> what postStart reported
  local probe
  probe=$(mktemp -d)
  env -u ANTHROPIC_BASE_URL -u CLAUDE_CODE_OAUTH_TOKEN \
    -u ANTHROPIC_AUTH_TOKEN -u ANTHROPIC_API_KEY HOME="$probe" "$@" \
    bash "$hooks/postStart.sh" 2>/dev/null
  cat "$probe/.cache/enchantments/claude-code.failures.reported" 2>/dev/null
}
warns() { start_report "$@" | grep -q 'ANTHROPIC_BASE_URL sends Claude'; }
silent() { ! warns "$@"; }
proxy=http://10.0.0.5:3456
check "a proxy without a token is reported" warns ANTHROPIC_BASE_URL=$proxy
check "the report names the host alone" test "$(
  start_report ANTHROPIC_BASE_URL='https://user:secret@Proxy.Example:8443/v1' \
    | grep -o 'sends Claude to [^,]*'
)" = "sends Claude to proxy.example"
check "Anthropic's own host is not reported" \
  silent ANTHROPIC_BASE_URL=https://API.Anthropic.com:443/
check "no base URL is not reported" silent
for token in CLAUDE_CODE_OAUTH_TOKEN ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY; do
  check "a proxy with $token set is not reported" \
    silent ANTHROPIC_BASE_URL=$proxy "$token=x"
done

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
