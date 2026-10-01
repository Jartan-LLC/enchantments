#!/bin/bash
set -e
source dev-container-features-test-lib

hooks=/usr/local/share/enchantments/claude-code

check "claude runs" claude --version
check "claude belongs to the user" test "$(stat -c %U "$(readlink -f "$HOME/.local/bin/claude")")" = vscode
check ".claude.json links into claude-data" test "$(readlink -f "$HOME/.claude.json")" = /home/vscode/.claude/claude.json
check "claude-data belongs to the user" test "$(stat -c %U /home/vscode/.claude)" = vscode
check "no failures recorded" test -z "$(ls "$HOME"/.cache/enchantments/*.failures* 2>/dev/null)"

# The attach refresh, against a stub claude that lists the plugins in $STUB_JSON.
stub=$(mktemp -d)
cat >"$stub/claude" <<'STUB'
#!/bin/bash
if [ "$*" = "plugins list --json" ]; then cat "$STUB_JSON"; else echo "$*" >>"$STUB_LOG"; fi
STUB
chmod +x "$stub/claude"
refresh() {  # plugins-json -> the refresh's claude calls, one per line
    printf '%s' "$1" >"$stub/plugins.json"
    : >"$stub/log"
    STUB_JSON=$stub/plugins.json STUB_LOG=$stub/log PATH="$stub:$PATH" bash "$hooks/postAttach.sh"
    cat "$stub/log"
}

plugins=$(jq -n --arg p "$PWD" '[{id: "a@m1", scope: "user"},
    {id: "b@m2", scope: "local", projectPath: $p}, {id: "d@m2", scope: "project", projectPath: $p},
    {id: "c@m3", scope: "local", projectPath: "/elsewhere"}]')
expected="plugins marketplace update m1
plugins marketplace update m2
plugins update a@m1 --scope user
plugins update b@m2 --scope local
plugins update d@m2 --scope project"
check "attach refreshes only user-scope plugins and this project's" test "$(refresh "$plugins")" = "$expected"

# A workspace in a subfolder: Claude records a local install under it, settings at the root.
root=$(mktemp -d)
git -C "$root" init -q && mkdir "$root/sub"
plugins=$(jq -n --arg w "$root/sub" --arg r "$root" '[{id: "b@m2", scope: "local", projectPath: $w},
    {id: "e@m4", scope: "project", projectPath: $r}, {id: "c@m3", scope: "local", projectPath: "/elsewhere"}]')
expected="plugins marketplace update m2
plugins marketplace update m4
plugins update b@m2 --scope local
plugins update e@m4 --scope project"
check "attach in a subfolder matches the workspace and the repo root" \
    test "$(cd "$root/sub" && refresh "$plugins")" = "$expected"

# A second claude on PATH, in a scratch HOME so the real report stays as it was.
probe=$(mktemp -d)
mkdir "$probe/bin" && ln -s /bin/true "$probe/bin/claude"
HOME=$probe PATH="$probe/bin:$PATH" bash "$hooks/postStart.sh" 2>/dev/null
check "a second claude on PATH is reported" grep -q 'more than one claude' "$probe/.cache/enchantments/claude-code.failures.reported"

reportResults
