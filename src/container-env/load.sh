#!/bin/bash
# Reads the container-env volume: its .env through direnv's dotenv parser,
# then one file per variable, each overriding the .env. Prints the variables
# that differ from the calling shell's as POSIX export lines, for profile.sh
# to eval. With --check, prints "problem <text>" and "note <text>" lines for
# postStart instead.
set -u
here=$(dirname "$(readlink -f "$0")")
dir=/mnt/enchantments/container-env
direnv=$here/direnv
problems=()
notes=()
declare -A inherited from_env

for name in $(compgen -e); do
  inherited[$name]=${!name}
done

# Prints the exported names whose values differ from the calling shell's.
changed() {
  local name
  for name in $(compgen -e); do
    [ "$name" = _ ] && continue
    if [ -z "${inherited[$name]+x}" ] \
      || [ "${inherited[$name]}" != "${!name}" ]; then
      echo "$name"
    fi
  done
}

if [ -f "$dir/.env" ]; then
  if [ ! -x "$direnv" ]; then
    problems+=("$dir/.env isn't loaded: direnv isn't installed; rebuild")
  elif exports=$("$direnv" dotenv bash "$dir/.env" 2>/dev/null); then
    eval "$exports"
    for name in $(changed); do
      from_env[$name]=1
    done
  else
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
    continue
  fi
  if ! value=$(<"$file"); then
    problems+=("$file is skipped: it can't be read")
    continue
  fi
  [ -n "${from_env[$name]+x}" ] \
    && notes+=("$name is set by both, and $file overrides $dir/.env")
  export "$name=$value"
done

if [ "${1-}" = --check ]; then
  for text in "${problems[@]}"; do
    echo "problem $text"
  done
  for text in "${notes[@]}"; do
    echo "note $text"
  done
  exit 0
fi
for name in $(changed); do
  value=${!name}
  printf "export %s='%s'\n" "$name" "${value//\'/\'\\\'\'}"
done
