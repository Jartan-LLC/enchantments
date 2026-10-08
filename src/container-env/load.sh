#!/bin/bash
# Reads the container-env volume: its .env through direnv's dotenv parser,
# then one file per variable, each overriding the .env. Prints the variables
# that differ from the calling shell's as POSIX export lines, for profile.sh
# to eval. With --check, prints "problem <text>" and "note <text>" lines for
# postStart instead.
#
# Loaded values never enter this shell, so no name can clobber the loader's
# own variables: the .env runs in a child whose environment is read back.
set -u
here=$(dirname "$(readlink -f "$0")")
dir=/mnt/enchantments/container-env
direnv=$here/direnv
mode=${1-}
problems=()
notes=()
declare -A before after values from_env

# A child bash's exported variables after it runs the code given, as
# NUL-separated NAME=value pairs. The code arrives on stdin, as an argument is
# held to 128 KiB, and the child writes the pairs with builtins only, so a
# PATH or an oversized value the code sets can't stop it. --check runs it on
# a clean environment, so the .env's names show even where the calling shell
# already holds the same value.
# shellcheck disable=SC2016 # the child expands it
dump='mapfile -t __container_env_names < <(compgen -e)
for __container_env_n in "${__container_env_names[@]}"; do
  printf "%s=%s\0" "$__container_env_n" "${!__container_env_n}"
done'
child_env() { # code
  if [ "$mode" = --check ]; then
    printf '%s\n%s\n' "$1" "$dump" \
      | env -i PATH="$PATH" bash --noprofile --norc 2>/dev/null
  else
    printf '%s\n%s\n' "$1" "$dump" | bash --noprofile --norc 2>/dev/null
  fi
}

# Reads child_env's pairs into the associative array named.
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

read_pairs before < <(child_env '')
if [ -f "$dir/.env" ]; then
  if [ ! -x "$direnv" ]; then
    problems+=("$dir/.env isn't loaded: direnv isn't installed; rebuild")
  elif exports=$("$direnv" dotenv bash "$dir/.env" 2>/dev/null); then
    read_pairs after < <(child_env "$exports")
    if [ "$mode" = --check ]; then
      while IFS= read -r line; do
        problems+=("$dir/.env: $line")
      done < <(printf '%s\n' "$exports" \
        | env -i PATH="$PATH" bash --noprofile --norc 2>&1 >/dev/null \
        | sed 's/^bash: line [0-9]*: //')
    fi
    for name in "${!after[@]}"; do
      if [ "${before[$name]-}" != "${after[$name]}" ] \
        || [ -z "${before[$name]+x}" ]; then
        values[$name]=${after[$name]}
        from_env[$name]=1
      fi
    done
  elif [ "$mode" = --check ]; then
    error=$("$direnv" dotenv bash "$dir/.env" 2>&1 >/dev/null \
      | sed 's/\x1b\[[0-9;]*m//g' | tr '\n' ' ')
    problems+=("$dir/.env isn't loaded: ${error% }")
  fi
fi

for file in "$dir"/*; do
  [ -f "$file" ] || continue
  name=${file##*/}
  if [[ ! $name =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    problems+=("$file is skipped: $name isn't a variable name")
  elif ! { values[$name]=$(<"$file"); } 2>/dev/null; then
    unset 'values[$name]'
    problems+=("$file is skipped: it can't be read")
  elif [ -n "${from_env[$name]+x}" ]; then
    notes+=("$name is set by both, and $file overrides $dir/.env")
  fi
done

# One string over 128 KiB, or an environment over ARG_MAX with a program's
# arguments, makes every program launch fail with "Argument list too long".
# The loaded values together stay within half of ARG_MAX, taken in name
# order so the same ones load each time.
budget=$(($(getconf ARG_MAX 2>/dev/null || echo 2097152) / 2))
kib=$((budget / 1024))
used=0
for name in "${!before[@]}"; do
  measure "$name" "${before[$name]}"
  used=$((used + length))
done
mapfile -t names < <(printf '%s\n' "${!values[@]}" | sort)
for name in "${names[@]}"; do
  [ -n "$name" ] || continue
  measure "$name" "${values[$name]}"
  if ! (export "$name=") 2>/dev/null; then
    problems+=("$name is skipped: bash doesn't let it be set")
  elif [ "$length" -gt 131072 ]; then
    problems+=("$name is skipped: its value is over 128 KiB")
  elif [ $((used + length)) -gt "$budget" ]; then
    problems+=("$name is skipped: the environment would pass $kib KiB")
  else
    used=$((used + length))
    if [ "$mode" != --check ] && { [ -z "${before[$name]+x}" ] \
      || [ "${before[$name]}" != "${values[$name]}" ]; }; then
      value=${values[$name]}
      printf "export %s='%s'\n" "$name" "${value//\'/\'\\\'\'}"
    fi
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
