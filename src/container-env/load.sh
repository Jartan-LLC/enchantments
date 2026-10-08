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

# A child's environment after it evals the code given, as NUL-separated
# NAME=value pairs. --check runs it on a clean environment, so the .env's
# names show even where the calling shell already holds the same value.
# shellcheck disable=SC2016 # the child expands $1
child_env() { # code
  if [ "$mode" = --check ]; then
    env -i PATH="$PATH" bash --noprofile --norc -c 'eval "$1"; exec env -0' \
      _ "$1"
  else
    bash --noprofile --norc -c 'eval "$1"; exec env -0' _ "$1"
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

# A variable longer than the kernel's limit for one string (128 KiB) makes
# every program launch fail with "Argument list too long".
fits() { # name value
  local LC_ALL=C
  [ $((${#1} + ${#2} + 2)) -le 131072 ]
}

read_pairs before < <(child_env '')
if [ -f "$dir/.env" ]; then
  if [ ! -x "$direnv" ]; then
    problems+=("$dir/.env isn't loaded: direnv isn't installed; rebuild")
  elif exports=$("$direnv" dotenv bash "$dir/.env" 2>/dev/null); then
    read_pairs after < <(child_env "$exports")
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

for name in "${!values[@]}"; do
  if ! (export "$name=") 2>/dev/null; then
    problems+=("$name is skipped: bash doesn't let it be set")
  elif ! fits "$name" "${values[$name]}"; then
    problems+=("$name is skipped: its value is over 128 KiB")
  elif [ "$mode" != --check ] && { [ -z "${before[$name]+x}" ] \
    || [ "${before[$name]}" != "${values[$name]}" ]; }; then
    value=${values[$name]}
    printf "export %s='%s'\n" "$name" "${value//\'/\'\\\'\'}"
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
