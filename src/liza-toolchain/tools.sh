# shellcheck shell=bash
# Where each tool onCreate installs lives, by the name its pin is recorded
# under in bin/.pins, so onCreate's pin check and postStart's agree. A pin
# missing here has no files, so onCreate reinstalls it at each create: add
# each new one. Sets mount, npm_tools and retry for both hooks.
mount=/mnt/enchantments/liza
npm_tools=(scip-python scip-typescript context7-mcp)
retry="retry: bash /usr/local/share/enchantments/liza-toolchain/onCreate.sh,"
retry+=" then, from the workspace folder:"
retry+=" bash /usr/local/share/enchantments/liza/updateContent.sh"

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

# Prints each file a pinned tool installs that isn't executable.
missing_files() { # pin-name
  local file
  while read -r file; do
    [ -z "$file" ] || [ -x "$file" ] || echo "$file"
  done <<<"$(tool_files "$1")"
}

# Succeeds when the pinned tool has files and every one is executable.
tool_installed() { # pin-name
  [ -n "$(tool_files "$1")" ] && [ -z "$(missing_files "$1")" ]
}
