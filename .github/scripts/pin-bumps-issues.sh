#!/bin/bash
# Keeps pin-bumps.yml's tracking issues in step with a pin-bumps.sh report:
# one per tool whose lookup failed, and one per Feature whose branch couldn't
# be pushed. Each is updated rather than duplicated, and closed by the first
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

title() { # lookup|push tool|id
  case $1 in
    lookup) echo "pin-bumps: $2 lookup failing" ;;
    push) echo "pin-bumps: $2 push refused" ;;
  esac
}

number_for() { # title
  jq -r --arg t "$1" '[.[] | select(.title == $t)][0].number // ""' \
    <<<"$open"
}

# Upstream text, made safe to quote: one line, no control characters or
# backticks, capped, and shown in a code block, so it renders as nothing and
# mentions no one.
quoted() { # text
  echo '```text'
  tr -d '\000-\037`' <<<"$1" | cut -c1-300
  echo '```'
}

# Opens the issue with the body file's text, or replaces an open one's body.
raise() { # title body-file
  local number
  number=$(number_for "$1")
  if [ -n "$number" ]; then
    gh issue edit "$number" --repo "$GITHUB_REPOSITORY" --body-file "$2"
  else
    gh issue create --repo "$GITHUB_REPOSITORY" --title "$1" \
      --label "$label" --body-file "$2"
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
      {
        echo "\`pin-bumps.yml\` couldn't look up \`$name\`'s newest version:"
        echo
        quoted "$reason"
        echo
        echo "Its Feature's pin-bump PR stays as it is until a run looks it" \
          "up again; that run closes this issue."
        echo
        echo "Last failure: $RUN_URL"
      } >"$body"
      raise "$(title lookup "$name")" "$body"
      ;;
    push/refused)
      {
        echo "\`pin-bumps.yml\` couldn't push \`pin-bumps/$name\`:"
        echo
        quoted "$reason"
        echo
        echo "Usually main has workflow changes the workflow's GitHub App," \
          "which has no \`workflows\` permission, can't push. Rebase the" \
          "branch by hand:"
        echo
        echo '```bash'
        echo "git fetch origin"
        echo "git switch pin-bumps/$name"
        echo "git rebase origin/main"
        echo "git push --force-with-lease"
        echo '```'
        echo
        echo "The next run that pushes the branch, or leaves it as it is," \
          "closes this issue."
        echo
        echo "Last refusal: $RUN_URL"
      } >"$body"
      raise "$(title push "$name")" "$body"
      ;;
    */ok) settle "$(title "$what" "$name")" ;;
  esac
done <"$report"
