# shellcheck shell=bash
# Sourced by shim.sh and deactivate.sh, which both work on the activation
# record.

# Prints "<path> <fingerprint>" for each existing file or symlink given, so
# activation can record what it created and deactivation can tell whether it has
# changed since. Readers split on the last space, so a symlink's target is
# hashed too.
fingerprint() {
  local f
  for f in "$@"; do
    if [ -L "$f" ]; then
      echo "$f link:$(readlink "$f" | sha256sum | cut -d' ' -f1)"
    elif [ -f "$f" ]; then
      echo "$f $(sha256sum <"$f" | cut -d' ' -f1)"
    fi
  done
}

# Puts a copy of file or symlink $1 at $2, replacing what's there without
# following it. A failed copy leaves $2 as it was.
put_copy() { # source dest
  rm -f -- "$2.liza-tmp"
  cp -P -p -- "$1" "$2.liza-tmp" && mv -f -T -- "$2.liza-tmp" "$2" && return
  rm -f -- "$2.liza-tmp"
  return 1
}

# Prints the absolute path of a path inside the git dir, for the clone at $1.
git_path() { # top  git-path
  local p
  p=$(git -C "$1" rev-parse --git-path "$2") || return
  [[ "$p" == /* ]] && echo "$p" || echo "$1/$p"
}

lib_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

# Prints what a jq filter, given activation-record.jq's definitions, reads from
# a record. The schema lives in that file only.
record_query() { # filter record
  jq -L "$lib_dir" -r "include \"activation-record\"; $1" "$2"
}

# Reads NUL-separated paths, relative to the clone's top, from stdin into the
# named array, each made absolute. A name holding a newline is skipped: the
# record keeps one path per line, and nothing Liza writes has one.
read_top_paths() { # array-name top
  local -n into=$1
  local path
  into=()
  while IFS= read -r -d '' path; do
    [[ "$path" == *$'\n'* ]] || into+=("$2/$path")
  done
}

# Prints the exclude-file line naming exactly one path relative to the clone's
# top: git would read \ * ? [ and a trailing space as pattern syntax.
exclude_line() { # relative-path
  local line=${1//\\/\\\\}
  line=${line//\*/\\*}
  line=${line//\?/\\?}
  line=${line//\[/\\[}
  [[ "$line" == *' ' ]] && line="${line% }\\ "
  printf '/%s\n' "$line"
}

# Prints the path, relative to the clone's top, that an exclude line names.
# Fails for a pattern, which may name more than one file.
exclude_line_path() { # line
  local rest=${1#/} path='' char
  while [ -n "$rest" ]; do
    char=${rest:0:1} rest=${rest:1}
    case "$char" in
      \\)
        [ -n "$rest" ] || return 1
        path+=${rest:0:1} rest=${rest:1}
        ;;
      '*' | '?' | '[') return 1 ;;
      *) path+=$char ;;
    esac
  done
  printf '%s\n' "$path"
}
