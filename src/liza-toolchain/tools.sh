# shellcheck shell=bash
# Where each tool onCreate installs lives, by the name its pin is recorded
# under in bin/.pins, so onCreate's pin check and postStart's agree. A pin
# missing here has no files, so it never counts as installed: add each new one.
mount=/mnt/enchantments/liza
npm_tools=(scip-python scip-typescript context7-mcp)

# Prints each file a pinned tool installs, one per line.
tool_files() { # pin-name
  local tool
  case $1 in
    ast-grep | yq | rtk | mdq | stacklit | scip-search | functional-clusters | \
      mdtoc | bash-policy | semble)
      echo "$mount/bin/$1"
      ;;
    npm-tools)
      for tool in "${npm_tools[@]}"; do
        echo "$mount/bin/$tool"
      done
      ;;
    uv) echo "$mount/lib/uv/uv" ;;
  esac
}

# Succeeds when the pinned tool has files and every one is executable.
tool_installed() { # pin-name
  local file files
  files=$(tool_files "$1")
  [ -n "$files" ] || return 1
  while read -r file; do
    [ -x "$file" ] || return 1
  done <<<"$files"
}
