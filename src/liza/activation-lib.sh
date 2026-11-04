# shellcheck shell=bash
# Activation's shared helpers, sourced by shim.sh, deactivate.sh and
# activation-steps.sh. Loaded once, however many of those source it.
[ -n "${activation_lib_loaded:-}" ] && return 0
activation_lib_loaded=1

# The contract, which activation links from one of contract_places below.
liza_contract="$HOME/.liza/CORE.md"
# liza-toolchain's presence marker.
# shellcheck disable=SC2034 # read by the scripts that source this
liza_toolchain=/usr/local/share/enchantments/liza-toolchain
# The shim's exit code when it refuses an init, which a caller reports as is.
# shellcheck disable=SC2034 # read by the scripts that source this
liza_refused=75
# The files init replaces without asking, which the shim holds in the record
# dir's clone-versions/ during init and merges with the clone's edits.
# shellcheck disable=SC2034 # read by the scripts that source this
merged_files=(.bash-policy.yaml .claudeignore)

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

# Succeeds when files or symlinks $1 and $2 have the same fingerprint, paths
# aside, and fails when either is missing.
same_content() { # a b
  local a b
  a=$(fingerprint "$1") b=$(fingerprint "$2")
  [ -n "$a" ] && [ "${a#"$1" }" = "${b#"$2" }" ]
}

# Puts a copy of file or symlink $1 at $2, replacing what's there without
# following it. A failed copy leaves $2 as it was. The copy goes through
# $2.liza-tmp, so a copy cut off by SIGKILL never takes the final name: a
# .liza-tmp is never a finished copy.
# Returns 0 explicitly: in an EXIT trap, a bare return gives the status the
# trap interrupted.
put_copy() { # source dest
  rm -f -- "$2.liza-tmp"
  cp -P -p -- "$1" "$2.liza-tmp" && mv -f -T -- "$2.liza-tmp" "$2" && return 0
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

# The folders where liza init writes, which with the clone's top level make
# up the area the shim lists before init. init_write_ignored in shim.sh names
# the paths init writes in each, and write_dirs below the folders: a folder
# added here needs its paths there, or its ignored files get no backup, and
# its provider flags in init_areas, or a symlink at it is never refused.
listed_dirs=(.claude .codex .cursor .opencode .copilot .github)
# Each of listed_dirs and the folders in it that liza init, or the shim's
# skill links, write in.
write_dirs=(.claude .claude/hooks .claude/skills .codex .codex/hooks .cursor
  .opencode .opencode/plugins .opencode/tools .copilot .copilot/hooks .github
  .github/hooks)

# Succeeds when path $1, relative to the clone's top, is in the area the shim
# lists: at the top level or under one of listed_dirs.
in_listed_area() { # relative-path
  local dir
  [[ "$1" != */* ]] && return 0
  for dir in "${listed_dirs[@]}"; do
    [[ "$1" == "$dir"/* ]] && return 0
  done
  return 1
}

# Prints the first of write_dirs under areas $2..., top-level names in the
# clone at $1, that is a symlink, dangling or not, and fails when none is.
# Activation and deactivation find the files they back up, record and undo
# by path, and git doesn't list files through a symlink: what they write
# through one, even into the clone, escapes the backup and the record.
symlinked_write_dir() { # top area...
  local dir
  for dir in "${write_dirs[@]}"; do
    in_list "${dir%%/*}" "${@:2}" || continue
    [ -L "$1/$dir" ] || continue
    echo "$1/$dir"
    return 0
  done
  return 1
}

# Prints the listed_dirs that liza init, given the shim's arguments $@, init
# among them, writes in, as Liza v0.10.0 does: .claude, where the shim links
# skills whatever the flags, and each provider flag's folders. With no
# provider flag and no goal, init asks which providers to set up, so it may
# write in any of them. A refusal over a folder the run never writes in, such
# as a symlinked .github with --claude alone, would block an activation that
# is safe.
init_areas() { # shim-args...
  local id chosen=false words=0
  echo .claude
  while [ $# -gt 0 ]; do
    case $1 in
      --provider)
        id=${2:-} chosen=true
        shift
        ;;
      --provider=*) id=${1#*=} chosen=true ;;
      -C | --project-root | --update-channel)
        id=''
        shift
        ;;
      --*) id=${1#--} id=${id%%=*} ;;
      -*) id='' ;;
      # The value of an init flag, such as --branch's, counts as a goal too:
      # init then refuses for want of a goal or provider, writing nothing.
      *) id='' words=$((words + 1)) ;;
    esac
    shift
    case $id in
      claude | codex | cursor | opencode | gemini | mistral | pi | copilot)
        chosen=true
        ;;
    esac
    case $id in
      codex | codex-acp) echo .codex ;;
      cursor) printf '%s\n' .codex .cursor ;;
      cursor-acp) echo .cursor ;;
      opencode | opencode-acp) echo .opencode ;;
      copilot) printf '%s\n' .copilot .github ;;
    esac
  done
  # The first word is the subcommand, init.
  if ! $chosen && [ "$words" -le 1 ]; then printf '%s\n' "${listed_dirs[@]}"; fi
}

# Prints the area, the top-level name, of each path the activation record of
# the clone at $1 lists and of each copy in its originals/: where deactivation
# writes.
recorded_areas() { # top
  local dir path
  dir=$(record_dir_of "$1") || return 1
  {
    record_query 'recorded_paths, overwritten_paths' "$dir/activation.json" \
      | while IFS= read -r path; do echo "${path#"$1"/}"; done
    finished_copies "$dir/originals" -printf '%P\n'
  } 2>/dev/null | cut -d/ -f1
}

# Prints the directory holding the activation record of the clone at $1.
record_dir_of() { # top
  git_path "$1" liza
}

# Runs find with actions $2... over the finished copies under originals/
# folder $1.
finished_copies() { # dir find-actions...
  find "$1" \( -type f -o -type l \) ! -name '*.liza-tmp' "${@:2}"
}

# Succeeds when the clone at $1 holds this shim's activation record, or the
# originals or held copies an interrupted activation saved. Empty folders left
# once the user moves those out don't count.
activated() { # top
  local dir
  dir=$(record_dir_of "$1" 2>/dev/null) || return 1
  [ -f "$dir/activation.json" ] && return 0
  [ -n "$(finished_copies "$dir/clone-versions" -print -quit 2>/dev/null)" ] \
    && return 0
  [ -n "$(finished_copies "$dir/originals" -print -quit 2>/dev/null)" ]
}

# Where activation links the contract, relative to the clone's top:
# CLAUDE.local.md, or .claude/CLAUDE.md when CLAUDE.local.md is the user's.
contract_places=(CLAUDE.local.md .claude/CLAUDE.md)

# Succeeds when the path is activation's contract link.
contract_link() { # path
  [ "$(readlink "$1")" = "$liza_contract" ]
}

# Succeeds when the clone at $1 has activation's contract link.
contract_linked() { # top
  local name
  for name in "${contract_places[@]}"; do
    contract_link "$1/$name" && return 0
  done
  return 1
}

# The name, in the record dir, under which the shim holds the user's
# CLAUDE.local.md while init runs.
# shellcheck disable=SC2034 # read by the scripts that source this
held_contract_name=${contract_places[0]}.held

# Moves the user's CLAUDE.local.md, held at $2, back to $1, over any contract
# link there. Fails when something else is at $1.
put_back_contract() { # path held
  contract_link "$1" && rm -f -- "$1"
  if [ -e "$1" ] || [ -L "$1" ]; then return 1; fi
  mv -- "$2" "$1"
}

# Liza's init writes to the checkout whose .git is the repo's git dir: from a
# linked worktree, that's the main checkout. Succeeds when the clone at $1 is
# that checkout; otherwise prints why it isn't activated, and fails.
main_checkout() { # top
  local common
  [ "$(git -C "$1" rev-parse --absolute-git-dir 2>/dev/null)" -ef "$1/.git" ] \
    && return 0
  common=$(git -C "$1" rev-parse --git-common-dir 2>/dev/null)
  [[ "$common" == /* ]] || common=$1/$common
  if [[ "$common" == */.git ]]; then
    echo "Liza activates only a repo's main checkout, ${common%/.git}"
  else
    echo "Liza activates only a checkout whose git dir is its own .git"
  fi
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
