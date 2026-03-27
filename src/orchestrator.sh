#!/usr/bin/env bash
# orchestrator.sh — Main installation flow controller
# Usage: bash src/orchestrator.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/logger.sh"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/utils.sh"

# ─── validate_prerequisites ───────────────────────────────────────────────────
validate_prerequisites() {
  log_info "Validating prerequisites..."

  # Bash 4+
  if (( BASH_VERSINFO[0] < 4 )); then
    log_error "Bash 4.0+ required. Current version: ${BASH_VERSION}"
    log_error "macOS users: install bash via Homebrew (brew install bash)"
    exit 1
  fi

  # curl or wget
  if ! check_command curl && ! check_command wget; then
    log_error "curl or wget is required but neither was found"
    exit 1
  fi

  # sudo
  if ! check_command sudo; then
    log_error "sudo is required but was not found"
    exit 1
  fi

  # tsort (GNU coreutils)
  if ! check_command tsort; then
    log_error "tsort (GNU coreutils) is required but was not found"
    exit 1
  fi

  # DISTRO must be set
  if [[ -z "${DISTRO:-}" ]]; then
    detect_distro
  fi

  log_success "Prerequisites OK (bash ${BASH_VERSION}, distro: ${DISTRO})"
}

# ─── resolve_deps ─────────────────────────────────────────────────────────────
# Recursively adds missing dependencies to the selection.
# Input: space-separated tool IDs
# Output (stdout): complete space-separated list including all deps
resolve_deps() {
  local tools="$1"
  local resolved=()
  local queue=($tools)
  declare -A visited

  while (( ${#queue[@]} > 0 )); do
    local tool="${queue[0]}"
    queue=("${queue[@]:1}")

    [[ -n "${visited[$tool]+x}" ]] && continue
    visited[$tool]=1
    resolved+=("$tool")

    local deps="${TOOL_DEPS[$tool]:-}"
    for dep in $deps; do
      if [[ -z "${visited[$dep]+x}" ]]; then
        queue+=("$dep")
      fi
    done
  done

  echo "${resolved[*]}"
}

# ─── copy_dotfiles ────────────────────────────────────────────────────────────
# Copies dotfiles from repo to $HOME, backing up existing files first.
# Returns list of copied filenames (newline-separated) via stdout.
copy_dotfiles() {
  local installed_tools="$1"
  local dotfiles_dir="${DOTFILES_DIR}/dotfiles"
  local backup_dir="${HOME_BACKUP_DIR}/$(date +%Y%m%d_%H%M%S)"
  local copied=()

  # Mapping: tool → dotfile(s) to copy
  declare -A _tool_dotfiles
  _tool_dotfiles[git]=".gitconfig"
  _tool_dotfiles[zsh]=".zshrc"
  _tool_dotfiles[alacritty]=".config/alacritty"
  _tool_dotfiles[zellij]=".config/zellij"
  _tool_dotfiles[neovim]=".config/nvim"

  local needs_backup=false
  local files_to_copy=()

  for tool in $installed_tools; do
    local dotfile="${_tool_dotfiles[$tool]:-}"
    [[ -z "$dotfile" ]] && continue

    local src="${dotfiles_dir}/${dotfile}"
    [[ ! -e "$src" ]] && continue

    local dst="${HOME}/${dotfile}"
    files_to_copy+=("$tool:$dotfile")

    if [[ -e "$dst" ]]; then
      needs_backup=true
    fi
  done

  # Create backup dir only if needed
  if $needs_backup; then
    mkdir -p "$backup_dir"
    log_info "Backing up existing dotfiles to: $backup_dir"
  fi

  for entry in "${files_to_copy[@]}"; do
    local tool="${entry%%:*}"
    local dotfile="${entry##*:}"
    local src="${dotfiles_dir}/${dotfile}"
    local dst="${HOME}/${dotfile}"

    if [[ -e "$dst" ]]; then
      local dst_parent
      dst_parent=$(dirname "${backup_dir}/${dotfile}")
      mkdir -p "$dst_parent"
      mv "$dst" "${backup_dir}/${dotfile}"
      log_info "  Backed up ~/${dotfile}"
    fi

    # Create parent directory if needed (e.g. .config/nvim)
    mkdir -p "$(dirname "$dst")"
    cp -r "$src" "$dst"
    log_success "  Copied ${dotfile} → ~/${dotfile}"
    copied+=("$dotfile")
  done

  printf '%s\n' "${copied[@]}"
}

# ─── write_install_record ─────────────────────────────────────────────────────
write_install_record() {
  local tools_installed="$1"    # space-separated
  local dotfiles_copied="$2"    # newline-separated
  local duration_seconds="$3"

  # Build JSON arrays
  local tools_json
  tools_json=$(printf '"%s",' $tools_installed | sed 's/,$//')

  local dotfiles_json
  if [[ -n "$dotfiles_copied" ]]; then
    dotfiles_json=$(echo "$dotfiles_copied" | while IFS= read -r f; do
      [[ -n "$f" ]] && printf '"%s",' "$f"
    done | sed 's/,$//')
  else
    dotfiles_json=""
  fi

  local timestamp
  timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  cat > "${DOTFILES_INSTALLED_FILE}" <<EOF
{
  "timestamp": "${timestamp}",
  "version": "${DOTFILES_VERSION}",
  "distro": "${DISTRO}",
  "tools_installed": [${tools_json}],
  "dotfiles_copied": [${dotfiles_json}],
  "duration_seconds": ${duration_seconds}
}
EOF

  log_success "Installation record saved: ${DOTFILES_INSTALLED_FILE}"
}

# ─── _run_installer ───────────────────────────────────────────────────────────
# Runs an installer script and filters its output:
#   - Lines from log_* (prefixed [INFO]/[✓]/[OK]/[ERROR]/[WARN]) → printed normally
#   - Everything else (apt-get, pacman, etc.) → single overwriting line
_run_installer() {
  local installer="$1"
  local _line _exit_code=0
  local _cols
  _cols=$(tput cols 2>/dev/null || echo 80)
  local _max=$(( _cols - 6 ))

  # Sync file: installer writes __SYNC__ to pipe → filter signals here → ask_user unblocks
  local _sync
  _sync=$(mktemp)
  export _DOTFILES_SYNC="$_sync"

  while IFS= read -r _line; do
    if [[ "$_line" == __EXIT:* ]]; then
      _exit_code="${_line#__EXIT:}"
    elif [[ "$_line" == __SYNC__ ]]; then
      # Filter caught up — signal ask_user it's safe to show prompt
      printf '\r\033[2K' # clear any ↳ line so prompt appears clean
      echo "1" > "$_sync"
    elif [[ "$_line" =~ \[(INFO|✓|OK|ERROR|WARN)\] ]]; then
      printf '\r\033[2K'
      case "${BASH_REMATCH[1]}" in
        INFO)  printf '\033[0;34m[INFO]\033[0m %s\n' "${_line#*\] }" ;;
        ✓|OK)  printf '\033[0;32m[✓]\033[0m %s\n'   "${_line#*\] }" ;;
        ERROR) printf '\033[0;31m[ERROR]\033[0m %s\n' "${_line#*\] }" >&2 ;;
        WARN)  printf '\033[0;33m[WARN]\033[0m %s\n'  "${_line#*\] }" ;;
      esac
    else
      printf '\r\033[2K  \033[2m↳ %.*s\033[0m' "$_max" "$_line"
    fi
  done < <({
    local _rc=0
    bash "$installer" 2>&1 || _rc=$?
    echo "__EXIT:${_rc}"
  })

  printf '\r\033[2K'
  rm -f "$_sync"
  unset _DOTFILES_SYNC
  return "$_exit_code"
}

# ─── main ─────────────────────────────────────────────────────────────────────
main() {
  local start_time
  start_time=$(date +%s)

  echo ""
  log_info "════════════════════════════════════════════════"
  log_info "          Dotfiles Installer v${DOTFILES_VERSION}"
  log_info "════════════════════════════════════════════════"
  echo ""

  # 1. Validate prerequisites
  validate_prerequisites

  # 2. Cache sudo credentials
  log_info "Caching sudo credentials..."
  sudo -v

  # 3. Parse manifest
  log_info "Loading manifest..."
  parse_manifest "${DOTFILES_DIR}/manifest.json"
  log_success "Loaded ${#TOOL_IDS[@]} tools from manifest"

  # 4. TUI — user selects tools
  echo ""
  local selected_tools
  selected_tools=$(bash "${SCRIPT_DIR}/tui.sh") || {
    log_error "Installation cancelled."
    exit 1
  }

  if [[ -z "$selected_tools" ]]; then
    log_warn "No tools selected. Exiting."
    exit 0
  fi

  echo ""
  log_info "Selected: ${selected_tools}"

  # 5. Resolve dependencies
  local full_tools
  full_tools=$(resolve_deps "$selected_tools")
  log_info "With dependencies: ${full_tools}"

  # 6. Topological sort
  local ordered_tools
  ordered_tools=$(topological_sort "$full_tools")
  log_info "Installation order: ${ordered_tools}"

  # 7. Install tools
  echo ""
  log_info "Starting installation..."
  echo ""

  local tool_array=($ordered_tools)
  local total=${#tool_array[@]}
  local count=0
  local failed_tools=()

  export DISTRO
  export DOTFILES_DIR

  for tool in "${tool_array[@]}"; do
    (( ++count ))
    local installer="${DOTFILES_DIR}/${TOOL_INSTALLER[$tool]}"

    log_info "[${count}/${total}] Installing ${TOOL_NAME[$tool]:-$tool}..."

    if [[ ! -f "$installer" ]]; then
      log_error "Installer not found: ${installer}"
      failed_tools+=("$tool")
      continue
    fi

    if _run_installer "$installer"; then
      log_success "[${count}/${total}] ${TOOL_NAME[$tool]:-$tool} done"
    else
      log_error "[${count}/${total}] ${TOOL_NAME[$tool]:-$tool} FAILED (exit $?)"
      failed_tools+=("$tool")
    fi
    echo ""
  done

  # 8. Copy dotfiles
  log_info "Copying dotfiles..."
  local dotfiles_copied
  dotfiles_copied=$(copy_dotfiles "$ordered_tools")

  # 9. Write installation record
  local end_time duration
  end_time=$(date +%s)
  duration=$(( end_time - start_time ))
  write_install_record "$ordered_tools" "$dotfiles_copied" "$duration"

  # 10. Summary
  echo ""
  log_info "════════════════════════════════════════════════"
  if (( ${#failed_tools[@]} == 0 )); then
    log_success "Installation completed successfully!"
  else
    log_warn "Installation completed with errors."
    log_warn "Failed tools: ${failed_tools[*]}"
  fi
  log_info "Tools installed: ${ordered_tools}"
  log_info "Duration: ${duration}s"
  log_info "Record: ${DOTFILES_INSTALLED_FILE}"
  log_info "════════════════════════════════════════════════"
  echo ""

  if (( ${#failed_tools[@]} > 0 )); then
    exit 1
  fi
}

main "$@"
