#!/bin/bash
set -e
# shellcheck source=/dev/null # the CLI adds it at test time
source dev-container-features-test-lib

dir=/mnt/enchantments/container-env
staged=/usr/local/share/enchantments/container-env

# A fresh login shell, so nothing the CLI probed at start leaks in.
login() { # shell variable
  env -i HOME="$HOME" PATH=/usr/bin:/bin "$1" -lc "printf '%s' \"\$$2\""
}
post_start() {
  bash "$staged/postStart.sh" 2>&1
}
reports() { # text
  post_start | grep -qF "$1"
}
exits_zero() {
  post_start >/dev/null
}

check "container-env is mounted" mountpoint -q "$dir"
check "the volume belongs to the user" test "$(stat -c %U "$dir")" = vscode
check "login shells run the loader" test -f /etc/profile.d/container-env.sh
check "the pinned direnv is installed" "$staged/direnv" version
check "an empty volume exports nothing" test -z "$(bash "$staged/load.sh")"
check "an empty volume reports nothing" test -z "$(post_start)"

cat >"$dir/.env" <<'EOF'
# a comment
export GREETING="hello world"
LINES="one\ntwo"
BOTH=from-env
QUOTE="it's"
REF=${GREETING}!
DEFAULTED=${NOT_SET_ANYWHERE:-fallback}
EOF
check "bash loads the .env" test "$(login bash GREETING)" = "hello world"
check "sh loads the .env" test "$(login sh GREETING)" = "hello world"
check "\\n becomes a newline" test "$(login bash LINES)" = $'one\ntwo'
check "the .env refers to its own values" \
  test "$(login bash REF)" = "hello world!"
check "a default applies" test "$(login bash DEFAULTED)" = fallback
check "a quote inside a value survives" test "$(login sh QUOTE)" = "it's"
check "BOTH comes from the .env" test "$(login bash BOTH)" = from-env

printf 'from-file\n\n' >"$dir/BOTH"
printf 'x-api-key: k\nx-team: core\n' >"$dir/HEADERS"
printf '%s' "it's \$HOME \`x\` \\n" >"$dir/LITERAL"
check "a variable's file overrides the .env" \
  test "$(login bash BOTH)" = from-file
check "the override is noted" reports "BOTH is set by both"
check "a multi-line file keeps its lines" \
  test "$(login bash HEADERS)" = $'x-api-key: k\nx-team: core'
check "sh gets the multi-line value" \
  test "$(login sh HEADERS)" = $'x-api-key: k\nx-team: core'
check "a file's value isn't shell-interpreted" \
  test "$(login sh LITERAL)" = "it's \$HOME \`x\` \\n"
check "a file overrides a value the shell already has" test "$(
  env -i HOME="$HOME" PATH=/usr/bin:/bin BOTH=inherited \
    bash -lc "printf %s \"\$BOTH\""
)" = from-file

printf A >"$dir/value"
printf B >"$dir/dir"
printf , >"$dir/IFS"
check "names the loader uses itself load like any other" \
  test "$(login bash value)$(login bash dir)" = AB
check "an IFS file doesn't stop the others loading" \
  test "$(login bash BOTH)" = from-file
rm "$dir/value" "$dir/dir" "$dir/IFS"

printf x >"$dir/bad-name"
echo 'NOT A LINE' >>"$dir/.env"
printf 5 >"$dir/UID"
head -c 140000 /dev/zero | tr '\0' a >"$dir/BIG"
printf x >"$dir/UNREAD"
chmod 000 "$dir/UNREAD"
check "an invalid name is reported" reports "bad-name is skipped"
check "an invalid .env is reported" reports "invalid line: NOT A LINE"
check "a name bash won't set is reported" reports "UID is skipped"
check "a value over 128 KiB is reported" reports "BIG is skipped"
check "an unreadable file is reported" reports "UNREAD is skipped"
check "postStart exits 0 while it reports" exits_zero
check "login shells still run programs, without errors" test -z "$(
  env -i HOME="$HOME" PATH=/usr/bin:/bin bash -lc /bin/true 2>&1
)"
check "an invalid .env loads nothing" test -z "$(login bash GREETING)"
check "the files still load" test "$(login bash BOTH)" = from-file

sudo mv "$staged/direnv" "$staged/direnv.off"
check "a missing direnv is reported" reports "direnv isn't installed"
sudo mv "$staged/direnv.off" "$staged/direnv"

check "nothing recorded at create" \
  test -z "$(ls "$HOME"/.cache/enchantments/*.failures* 2>/dev/null)"

reportResults
