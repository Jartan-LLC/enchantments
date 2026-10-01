#!/bin/bash
set -e
source dev-container-features-test-lib

hooks=/usr/local/share/enchantments/claude-code

check "claude runs" claude --version
check "claude belongs to the user" test "$(stat -c %U "$(readlink -f "$HOME/.local/bin/claude")")" = vscode
check ".claude.json links into claude-data" test "$(readlink -f "$HOME/.claude.json")" = /home/vscode/.claude/claude.json
check "claude-data belongs to the user" test "$(stat -c %U /home/vscode/.claude)" = vscode
check "no failures recorded" test -z "$(ls "$HOME"/.cache/enchantments/*.failures* 2>/dev/null)"

# The attach refresh, against a stub claude that lists plugins of every scope and project.
stub=$(mktemp -d)
cat >"$stub/claude" <<'STUB'
#!/bin/bash
if [ "$*" = "plugins list --json" ]; then
    jq -n --arg p "$PWD" '[{id: "a@m1", scope: "user"},
        {id: "b@m2", scope: "local", projectPath: $p}, {id: "d@m2", scope: "project", projectPath: $p},
        {id: "c@m3", scope: "local", projectPath: "/elsewhere"}]'
else
    echo "$*" >>"$STUB_LOG"
fi
STUB
chmod +x "$stub/claude"
STUB_LOG=$stub/log PATH="$stub:$PATH" bash "$hooks/postAttach.sh"
expected="plugins marketplace update m1
plugins marketplace update m2
plugins update a@m1 --scope user
plugins update b@m2 --scope local
plugins update d@m2 --scope project"
check "attach refreshes only user-scope plugins and this project's" test "$(cat "$stub/log")" = "$expected"

# A second claude on PATH, in a scratch HOME so the real report stays as it was.
probe=$(mktemp -d)
mkdir "$probe/bin" && ln -s /bin/true "$probe/bin/claude"
HOME=$probe PATH="$probe/bin:$PATH" bash "$hooks/postStart.sh" 2>/dev/null
check "a second claude on PATH is reported" grep -q 'more than one claude' "$probe/.cache/enchantments/claude-code.failures.reported"

reportResults
