#!/bin/bash
# Keeps pin-bumps.yml's tracking issues in step with a pin-bumps.sh report:
# one per tool whose lookup failed ("pin-bumps: <tool> lookup failing"), and
# one per Feature whose branch couldn't be moved ("pin-bumps: <id> push
# refused"). Each is updated rather than duplicated, and closed by the first
# run that reports that tool or Feature clean. Needs GH_TOKEN with issues
# write, GITHUB_REPOSITORY and RUN_URL.
set -euo pipefail
report=${1:?usage: pin-bumps-issues.sh <report>}
: "${GITHUB_REPOSITORY:?}" "${RUN_URL:?}"
label=pin-bumps
body=$(mktemp)
trap 'rm -f "$body"' EXIT

gh label create "$label" --repo "$GITHUB_REPOSITORY" --force \
  --color fbca04 --description "Tracking issues from pin-bumps.yml"
open=$(gh issue list --repo "$GITHUB_REPOSITORY" --state open \
  --label "$label" --limit 200 --json number,title)

number_for() { # title
  jq -r --arg t "$1" '[.[] | select(.title == $t)][0].number // ""' \
    <<<"$open"
}

# Opens the issue with the body in $body, or replaces an open one's body.
raise() { # title
  local number
  number=$(number_for "$1")
  if [ -n "$number" ]; then
    gh issue edit "$number" --repo "$GITHUB_REPOSITORY" --body-file "$body"
  else
    gh issue create --repo "$GITHUB_REPOSITORY" --title "$1" \
      --label "$label" --body-file "$body"
  fi
}

settle() { # title
  local number
  number=$(number_for "$1")
  [ -z "$number" ] || gh issue close "$number" \
    --repo "$GITHUB_REPOSITORY" --comment "Resolved as of $RUN_URL"
}

while IFS=$'\t' read -r what name state reason; do
  case $what/$state in
    lookup/fail)
      cat >"$body" <<EOF
\`pin-bumps.yml\` couldn't look up \`$name\`'s newest version:

> $reason

Its Feature's pin-bump PR stays as it is until a run looks it up again; that
run closes this issue.

Last failure: $RUN_URL
EOF
      raise "pin-bumps: $name lookup failing"
      ;;
    lookup/ok) settle "pin-bumps: $name lookup failing" ;;
    push/refused)
      cat >"$body" <<EOF
\`pin-bumps.yml\` can't move \`pin-bumps/$name\` onto main: main has
workflow changes, and the workflow's GitHub App has no \`workflows\`
permission. Rebase the branch by hand:

\`\`\`bash
git fetch origin
git switch pin-bumps/$name
git rebase origin/main
git push --force-with-lease
\`\`\`

The next run then resumes, and closes this issue.

Last refusal: $RUN_URL
EOF
      raise "pin-bumps: $name push refused"
      ;;
    push/ok) settle "pin-bumps: $name push refused" ;;
  esac
done <"$report"
