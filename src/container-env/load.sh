#!/bin/bash
# Reads the container-env volume: its .env through direnv's dotenv parser,
# then one file per variable, each overriding the .env. Prints the variables
# that differ from the calling shell's as POSIX export lines, for profile.sh
# to eval. With --check, prints "problem <text>" and "note <text>" lines for
# postStart instead.
#
# Loaded values are kept as array entries, never as this shell's variables,
# so no loaded name can clobber the loader's own: the .env and the caller's
# environment are read through children.
set -u
here=$(dirname "$(readlink -f "$0")")
dir=/mnt/enchantments/container-env
direnv=$here/direnv
mode=${1-}
problems=()
notes=()
declare -A before values

# Appended to the code a child bash reads on stdin: prints the child's
# exported variables as NUL-separated NAME=value pairs. Stdin, because one
# argument can't pass 128 KiB; builtins only, so a PATH or a large value the
# code sets can't stop it. Names starting __container_env_ are the dump's own,
# and are left out.
# shellcheck disable=SC2016 # the child expands it
dump='mapfile -t __container_env_names < <(compgen -e)
for __container_env_n in "${__container_env_names[@]}"; do
  [[ $__container_env_n == __container_env_* ]] && continue
  printf "%s=%s\0" "$__container_env_n" "${!__container_env_n}"
done'

# Reads NUL-separated pairs into the associative array named.
read_pairs() { # array
  local -n into=$1
  local pair
  # shellcheck disable=SC2034 # into is a nameref to the caller's array
  while IFS= read -r -d '' pair; do
    into[${pair%%=*}]=${pair#*=}
  done
}

# The bytes a variable takes in the environment, into $length.
measure() { # name value
  local LC_ALL=C
  length=$((${#1} + ${#2} + 2))
}

valid_name() { # name
  local LC_ALL=C
  [[ $1 =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
}

read_pairs before < <(printf '%s\n' "$dump" | bash --noprofile --norc)

# direnv parses the .env in the caller's environment and prints its values
# expanded, so its export lines run on a clean one: what comes back is exactly
# what the .env sets, apart from the PWD and SHLVL bash exports itself. Under
# --check, direnv's error, or the lines bash rejects, are reported.
errors=/dev/null
[ "$mode" = --check ] && errors=$(mktemp)
if [ -f "$dir/.env" ]; then
  if [ ! -x "$direnv" ]; then
    problems+=("$dir/.env isn't loaded: direnv isn't installed; rebuild")
  elif ! exports=$("$direnv" dotenv bash "$dir/.env" 2>"$errors"); then
    error=$(sed 's/\x1b\[[0-9;]*m//g' "$errors" | tr '\n' ' ')
    problems+=("$dir/.env isn't loaded: ${error% }")
  else
    read_pairs values < <(printf '%s\n%s\n' "$exports" "$dump" \
      | env -i bash --noprofile --norc 2>"$errors")
    unset 'values[PWD]' 'values[SHLVL]'
    # A name bash won't set comes back with bash's own value; the child's
    # stderr has reported it already.
    for name in "${!values[@]}"; do
      (export "$name=") 2>/dev/null || unset 'values[$name]'
    done
    while IFS= read -r line; do
      problems+=("$dir/.env: ${line#bash: line *: }")
    done <"$errors"
  fi
fi
[ "$errors" = /dev/null ] || rm -f "$errors"

for file in "$dir"/*; do
  [ -f "$file" ] || continue
  name=${file##*/}
  if ! valid_name "$name"; then
    problems+=("$file is skipped: $name isn't a variable name")
  elif [ ! -r "$file" ]; then
    problems+=("$file is skipped: it can't be read")
  elif [ "$(stat -L -c %s "$file")" -gt 131072 ]; then
    problems+=("$name is skipped: its value is over 128 KiB")
  else
    [ -n "${values[$name]+x}" ] \
      && notes+=("$name is set by both, and $file overrides $dir/.env")
    values[$name]=$(<"$file")
  fi
done

# One string over 128 KiB, or an environment over ARG_MAX with a program's
# arguments, makes every program launch fail with "Argument list too long".
# The environment stays within half of ARG_MAX, taking the loaded values in
# name order so the same ones load each time.
budget=$(($(getconf ARG_MAX 2>/dev/null || echo 2097152) / 2))
limit="$((budget / 1024)) KiB, half of ARG_MAX"
used=0
for name in "${!before[@]}"; do
  measure "$name" "${before[$name]}"
  used=$((used + length))
done
mapfile -t names < <(printf '%s\n' "${!values[@]}" | LC_ALL=C sort)
for name in "${names[@]}"; do
  [ -n "$name" ] || continue
  measure "$name" "${values[$name]}"
  new=$length
  old=0
  if [ -n "${before[$name]+x}" ]; then
    [ "${before[$name]}" = "${values[$name]}" ] && continue
    measure "$name" "${before[$name]}"
    old=$length
  fi
  if ! (export "$name=") 2>/dev/null; then
    problems+=("$name is skipped: bash doesn't let it be set")
  elif [ "$new" -gt 131072 ]; then
    problems+=("$name is skipped: its value is over 128 KiB")
  elif [ $((used + new - old)) -gt "$budget" ]; then
    problems+=("$name is skipped: the environment would pass $limit")
  else
    used=$((used + new - old))
    value=${values[$name]}
    [ "$mode" = --check ] \
      || printf "command export %s='%s'\n" "$name" "${value//\'/\'\\\'\'}"
  fi
done

if [ "$mode" = --check ]; then
  for text in "${problems[@]}"; do
    echo "problem $text"
  done
  for text in "${notes[@]}"; do
    echo "note $text"
  done
fi
