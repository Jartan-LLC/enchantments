# shellcheck shell=bash
# Acting as the pin-bumps App, for the scripts that push and open PRs as it
# (docs/repository-settings.md, "The pin-bump App"). Sourced.

# Set by setup_app: the App's commit identity, and the header its git requests
# carry.
bot_login=''
bot_email=''
auth=''

setup_app() {
  : "${GH_TOKEN:?}" "${APP_SLUG:?}" "${GITHUB_REPOSITORY:?}"
  bot_login="${APP_SLUG}[bot]"
  bot_email="$(gh api "users/$APP_SLUG%5Bbot%5D" --jq .id)+$bot_login"
  bot_email+="@users.noreply.github.com"
  auth="AUTHORIZATION: basic $(printf 'x-access-token:%s' "$GH_TOKEN" \
    | base64 -w0)"
  echo "::add-mask::${auth#AUTHORIZATION: basic }"
}

# Runs git with the App's auth header, in the environment rather than argv.
git_authed() {
  GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=http.https://github.com/.extraheader \
    GIT_CONFIG_VALUE_0="$auth" git "$@"
}
