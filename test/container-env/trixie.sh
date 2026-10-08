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

mv "$dir/.env" "$dir/.env.saved"
# A PATH without env or bash in it mustn't stop the .env being read back.
printf 'PATHED=1\nPATH=/opt/tools/bin\n' >"$dir/.env"
check "a .env that sets PATH still loads" test "$(login bash PATHED)" = 1
{
  echo SMALL=1
  printf 'HUGE='
  head -c 140000 /dev/zero | tr '\0' a
  echo
} >"$dir/.env"
check "a .env value over 128 KiB is reported" reports "HUGE is skipped"
check "the rest of that .env loads" test "$(login bash SMALL)" = 1
printf 'export FOO.BAR=x\nKEPT=1\n' >"$dir/.env"
check "a .env line bash rejects is reported" reports "FOO.BAR"
check "the rest of that .env loads too" test "$(login bash KEPT)" = 1
chmod 000 "$dir/.env"
check "an unreadable .env is reported" reports "permission denied"
mv "$dir/.env.saved" "$dir/.env"

# The loader keeps the environment within half of ARG_MAX.
budget=$(($(getconf ARG_MAX) / 2))
for i in $(seq -w $((budget / 120000 + 2))); do
  head -c 120000 /dev/zero | tr '\0' a >"$dir/FILL$i"
done
check "values past the environment budget are reported" \
  reports "the environment would pass"
check "values within the budget still load" test -n "$(login bash FILL01)"
check "past the budget, login shells still run programs" test -z "$(
  env -i HOME="$HOME" PATH=/usr/bin:/bin bash -lc /bin/true 2>&1
)"
rm "$dir"/FILL*

# Values the shell already holds count once, as in a nested login shell.
fat=$(head -c 100000 /dev/zero | tr '\0' b)
held=()
for i in $(seq $((budget * 3 / 4 / 100000))); do
  printf '%s' "$fat" >"$dir/FAT$i"
  held+=("FAT$i=$fat")
done
# Counted once, ZLAST fits; counted twice, the held values leave it no room.
head -c 120000 /dev/zero | tr '\0' z >"$dir/ZLAST"
check "values the shell already holds don't count twice" test "$(
  env -i HOME="$HOME" PATH=/usr/bin:/bin "${held[@]}" \
    bash -lc "printf %s \"\$ZLAST\" | wc -c"
)" = 120000
rm "$dir"/FAT* "$dir/ZLAST"

# An earlier profile script's readonly name doesn't stop a dash login shell.
echo 'readonly HELD=mine' | sudo tee /etc/profile.d/00-held.sh >/dev/null
printf theirs >"$dir/HELD"
printf after >"$dir/ZAFTER"
check "a readonly name doesn't stop sh loading the rest" \
  test "$(login sh ZAFTER)" = after
sudo rm /etc/profile.d/00-held.sh
rm "$dir/HELD" "$dir/ZAFTER"

# The .env child's own variables are reserved.
mv "$dir/.env" "$dir/.env.saved"
printf '__container_env_n=x\nAFTER_RESERVED=1\n' >"$dir/.env"
check "a .env name the loader reserves is left out" \
  test -z "$(login bash __container_env_n)"
check "and the rest of that .env loads" \
  test "$(login bash AFTER_RESERVED)" = 1
mv "$dir/.env.saved" "$dir/.env"

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

sudo chmod 000 "$staged/load.sh"
check "a loader that fails is reported" reports "the loader failed"
sudo chmod 755 "$staged/load.sh"

check "nothing recorded at create" \
  test -z "$(ls "$HOME"/.cache/enchantments/*.failures* 2>/dev/null)"

reportResults
