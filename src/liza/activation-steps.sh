# shellcheck shell=bash source-path=SCRIPTDIR
# The activation sequence. updateContent.sh runs every step; liza-activate runs
# only the steps that act on a clone, so the two callers share them.

steps_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
# shellcheck source=record_failure.sh
. "$steps_dir/record_failure.sh"
# shellcheck source=claude_ready.sh
. "$steps_dir/claude_ready.sh"
# shellcheck source=activation-lib.sh
. "$steps_dir/activation-lib.sh"
# liza-toolchain stages configure.args, env.append and AGENT_TOOLS.md here for
# these steps: renaming one means releasing both Features together.
toolchain=$liza_toolchain
# context7's registration as activation makes it.
context7_command=$HOME/.liza/bin/context7-mcp
claude_code=/usr/local/share/enchantments/claude-code
liza_bin=$HOME/.liza/libexec/liza

# Succeeds when ~/.liza is this project's volume, which onCreate links.
# Otherwise records why, ending with what the caller skips, and fails.
liza_volume_ready() { # consequence
  [ "$HOME/.liza" -ef /mnt/enchantments/liza ] && return 0
  record_failure liza "$HOME/.liza isn't the liza volume (see liza's" \
    "report): $1"
  return 1
}

# Sets top to the root of the clone around the working directory. Outside a
# repository, prints a note and fails; any other git error is recorded.
find_clone() {
  local out
  if out=$(git rev-parse --show-toplevel 2>&1); then
    top=$out
    return 0
  fi
  case "$out" in
    *"not a git repository"*)
      echo "liza: $PWD isn't in a git repository, so no clone is activated" \
        >&2
      ;;
    *)
      record_failure liza "git can't read $PWD, so Liza isn't activated" \
        "there: ${out//$'\n'/ }"
      ;;
  esac
  return 1
}

# Removes context7's registration for the clone at $top, only when it's the one
# activation makes: a context7 you registered yourself stays. liza-deactivate
# --tools runs this alone.
remove_context7() {
  claude_ready liza "context7's registration isn't checked" || return 1
  jq -e --arg p "$top" --arg c "$context7_command" \
    '.projects[$p].mcpServers.context7.command == $c' "$claude_json" \
    >/dev/null 2>&1 || return 0
  (cd "$top" && "$claude_bin" mcp remove --scope local context7 >/dev/null) \
    && return 0
  record_failure liza "removing context7's registration failed; retry from" \
    "$top: liza-deactivate --tools"
  return 1
}

# Without the toolchain, removes the context7 registration it made. Without
# claude-code, none was made here.
remove_context7_without_toolchain() {
  [ -d "$toolchain" ] || [ ! -d "$claude_code" ] || remove_context7
}

# With the toolchain, writes its env.sh and profile hook. configure picks the
# profile files from $SHELL, which isn't the user's shell during create.
configure_toolchain() {
  local env=$HOME/.liza/toolchain/env.sh args line
  [ -d "$toolchain" ] || return 0
  mapfile -t args <"$toolchain/configure.args"
  if ! SHELL=$(getent passwd "$(id -un)" | cut -d: -f7) \
    "$liza_bin" toolchain configure "${args[@]}" </dev/null >/dev/null; then
    record_failure liza "liza toolchain configure failed, so the toolchain" \
      "isn't on PATH for your shells"
    return
  fi
  # configure may keep the file it wrote before.
  while IFS= read -r line; do
    grep -qxF -- "$line" "$env" || echo "$line" >>"$env"
  done <"$toolchain/env.append"
}

# Refreshes Liza's contracts and skills to match the binary, with the
# AGENT_TOOLS.md that lists only the tools this container has.
set_up_liza() {
  local agent_tools=$steps_dir/AGENT_TOOLS.minimal.md
  [ -d "$toolchain" ] && agent_tools=$toolchain/AGENT_TOOLS.md
  "$liza_bin" setup --force --yes --agent-tools "$agent_tools" </dev/null \
    >/dev/null \
    || record_failure liza "liza setup failed, so its contracts and skills" \
      "may not match its binary"
}

# setup links every skill into ~/.claude/skills, which would load them in every
# container sharing claude-data; activate_clone links them into the clone.
unlink_global_skills() {
  local link
  for link in "$HOME"/.claude/skills/*; do
    [ -L "$link" ] || continue
    case "$(readlink "$link")" in
      "$HOME"/.liza/skills/* | /mnt/enchantments/liza/skills/*)
        rm -f -- "$link"
        ;;
    esac
  done
}

# Activates the clone at $top through the shim, which keeps every write
# local to it. Arguments go to liza init.
activate_clone() { # liza-init-args...
  local refusal rc
  refusal=$(mktemp) || {
    record_failure liza "no temporary file, so Liza isn't activated in $top"
    return
  }
  (cd "$top" && LIZA_SHIM_REFUSAL=$refusal \
    bash "$steps_dir/shim.sh" init --claude --yes "$@" </dev/null)
  rc=$?
  if [ "$rc" -eq "$liza_refused" ]; then
    record_failure liza "Liza isn't activated in $top: $(cat "$refusal")"
  elif [ "$rc" -ne 0 ]; then
    record_failure liza "liza init failed in $top, so Liza isn't active" \
      "there; retry from it: liza-activate"
  fi
  rm -f "$refusal"
  [ "$rc" -eq 0 ] || return
  # Never replaced: a context7 you registered yourself stays.
  if [ -d "$toolchain" ] && [ -d "$claude_code" ] \
    && claude_ready liza "context7 isn't registered"; then
    (cd "$top" && { "$claude_bin" mcp get context7 >/dev/null 2>&1 \
      || "$claude_bin" mcp add --scope local context7 \
        -- "$context7_command" >/dev/null; }) \
      || record_failure liza "registering context7 failed; retry from $top:" \
        "liza-activate"
  fi
  [ "$(readlink -f "$top/CLAUDE.local.md")" \
    = "$(readlink -f "$liza_contract")" ] \
    || record_failure liza "$top/CLAUDE.local.md is your own file, so" \
      "Liza's contract isn't loaded there; move it aside, then run:" \
      "liza-activate"
}
