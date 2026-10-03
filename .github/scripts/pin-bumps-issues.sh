#!/bin/bash
# Keeps pin-bumps.yml's tracking issues in step with a pin-bumps.sh report,
# whose rows pin-bumps.sh's header gives: one issue per tool whose lookup
# failed, and one per Feature whose # pin headers are invalid or whose
# branch couldn't be pushed. Each is updated rather than duplicated, and
# closed by the first run that reports that tool or Feature clean. Needs
# GITHUB_REPOSITORY, RUN_URL, and GH_TOKEN with issues write.
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

title() { # lookup|pins|push tool|id
  case $1 in
    lookup) echo "pin-bumps: $2 lookup failing" ;;
    pins) echo "pin-bumps: $2 pin headers invalid" ;;
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
        echo "Fix the cause above if it's in the tool's \`pins.sh\` entry or" \
          "\`.github/scripts/pin_lookups.sh\`; an upstream outage clears by" \
          "itself. The next run that looks it up closes this issue."
        echo
        echo "Last failure: $RUN_URL"
      } >"$body"
      raise "$(title lookup "$name")" "$body"
      ;;
    pins/fail)
      {
        echo "\`pin-bumps.yml\` found a problem in" \
          "\`src/$name/pins.sh\`'s \`# pin\` headers:"
        echo
        quoted "$reason"
        echo
        echo "Fix it; the next run closes this issue. Until then, none of" \
          "the Feature's pins are looked up, and every run fails."
        echo
        echo "Last failure: $RUN_URL"
      } >"$body"
      raise "$(title pins "$name")" "$body"
      ;;
    push/refused)
      {
        echo "\`pin-bumps.yml\` couldn't push \`pin-bumps/$name\`:"
        echo
        quoted "$reason"
        echo
        echo "This usually means main has changes under" \
          "\`.github/workflows/\`, which the workflow's GitHub App has no" \
          "permission to push. Rebase the branch by hand:"
        echo
        echo '```bash'
        echo "git fetch origin"
        echo "git switch pin-bumps/$name"
        echo "git rebase origin/main"
        echo "git push --force-with-lease"
        echo '```'
        echo
        echo "The next run that pushes the branch, or finds nothing to push," \
          "closes this issue."
        echo
        echo "Last refusal: $RUN_URL"
      } >"$body"
      raise "$(title push "$name")" "$body"
      ;;
    lookup/ok | pins/ok | push/ok) settle "$(title "$what" "$name")" ;;
    *) echo "unknown report row: $what/$state" >&2 && exit 1 ;;
  esac
done <"$report"
