# shellcheck shell=bash
# Activation's shared helpers, sourced by shim.sh, deactivate.sh and
# activation-steps.sh. Loaded once, however many of those source it.
[ -n "${activation_lib_loaded:-}" ] && return 0
activation_lib_loaded=1

# The contract, which activation links from the clone's CLAUDE.local.md.
liza_contract="$HOME/.liza/CORE.md"
# liza-toolchain's presence marker.
# shellcheck disable=SC2034 # read by the scripts that source this
liza_toolchain=/usr/local/share/enchantments/liza-toolchain
# The shim's exit code when it refuses an init, which a caller reports as is.
# shellcheck disable=SC2034 # read by the scripts that source this
liza_refused=75

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

# Succeeds when the first argument equals one of the others. A loop, not a pipe
# into grep -q, which can lose to SIGPIPE under pipefail.
in_list() { # value list...
  local item
  for item in "${@:2}"; do [ "$item" = "$1" ] && return 0; done
  return 1
}

# Prints the absolute path of a path inside the git dir, for the clone at $1.
git_path() { # top  git-path
  local p
  p=$(git -C "$1" rev-parse --git-path "$2") || return
  [[ "$p" == /* ]] && echo "$p" || echo "$1/$p"
}

lib_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

# Runs a jq filter with activation-record.jq's definitions, where the record's
# schema lives. Further arguments go to jq.
record_jq() { # filter jq-args...
  jq -L "$lib_dir" "include \"activation-record\"; $1" "${@:2}"
}

# Prints, one per line, what a filter reads from a record.
record_query() { # filter record
  record_jq "$1" -r "$2"
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

# Prints the directory holding the activation record of the clone at $1.
record_dir_of() { # top
  git_path "$1" liza
}

# Succeeds when the clone at $1 holds this shim's activation record, or the
# originals an interrupted activation saved.
activated() { # top
  local dir
  dir=$(record_dir_of "$1" 2>/dev/null) || return 1
  [ -f "$dir/activation.json" ] || [ -d "$dir/originals" ]
}

# Succeeds when the clone at $1's CLAUDE.local.md is activation's link.
contract_linked() { # top
  [ "$(readlink "$1/CLAUDE.local.md")" = "$liza_contract" ]
}

# Linked worktrees of a repo share its git hooks and exclude file, so only one
# of them is activated at a time. Prints another activated worktree of the
# clone at $1, and fails with 1 when there's none, or with 2 when git can't
# list the worktrees: -z needs git 2.36.
other_activation() { # top
  local line wt
  git -C "$1" worktree list --porcelain -z >/dev/null 2>&1 || return 2
  while IFS= read -r -d '' line; do
    [[ "$line" == "worktree "* ]] || continue
    wt=${line#worktree }
    [ "$wt" -ef "$1" ] && continue
    activated "$wt" || continue
    printf '%s\n' "$wt"
    return 0
  done < <(git -C "$1" worktree list --porcelain -z)
  return 1
}

# Succeeds for a gate value that's on.
truthy() { # value
  case "${1,,}" in 1 | true | yes | on) ;; *) return 1 ;; esac
}

# With the stacklit or SCIP gate on, Liza's init installs code-index hooks, and
# fails rather than replace one it doesn't manage, a dangling link included.
# Prints the first such hook of the clone at $1; fails with 1 when there's none
# or no gate asks, and with 2 when git can't locate the hooks.
own_index_hook() { # top
  local dir name
  truthy "${LIZA_ENABLE_STACKLIT:-}" || truthy "${LIZA_ENABLE_SCIP_SEARCH:-}" \
    || return 1
  dir=$(git_path "$1" hooks 2>/dev/null) || return 2
  for name in post-checkout post-commit post-merge post-rewrite; do
    [ -e "$dir/$name" ] || [ -L "$dir/$name" ] || continue
    grep -qs 'PAIRING-INDEX-HOOK: managed' "$dir/$name" && continue
    echo "$name"
    return 0
  done
  return 1
}
