# shellcheck shell=bash
# Where each tool onCreate installs lives, by the name its pin is recorded
# under in bin/.pins, so onCreate's pin check and postStart's agree.
toolchain=/mnt/enchantments/liza
npm_tools=(scip-python scip-typescript context7-mcp)

# Prints each file a pinned tool installs, one per line.
tool_files() { # pin-name
  local tool
  case $1 in
    npm-tools)
      for tool in "${npm_tools[@]}"; do
        echo "$toolchain/bin/$tool"
      done
      ;;
    uv) echo "$toolchain/lib/uv/uv" ;;
    *) echo "$toolchain/bin/$1" ;;
  esac
}

# Succeeds when every file the pinned tool installs is executable.
tool_installed() { # pin-name
  local file
  while read -r file; do
    [ -x "$file" ] || return 1
  done < <(tool_files "$1")
}
