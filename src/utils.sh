#!/usr/bin/env bash
# utils.sh — Shared utility functions
# Source this file: source src/utils.sh
# Requires: src/logger.sh already sourced

# ─── check_command ────────────────────────────────────────────────────────────
# Returns 0 if command exists in PATH, 1 otherwise.
# Usage: check_command git
check_command() {
  command -v "$1" &>/dev/null
}

# ─── detect_distro ────────────────────────────────────────────────────────────
# Reads /etc/os-release and sets + exports DISTRO.
# Supported: ubuntu, debian, arch, fedora
# Exits with error if unsupported.
detect_distro() {
  if [[ ! -f /etc/os-release ]]; then
    log_error "Cannot detect distro: /etc/os-release not found"
    return 1
  fi

  local id
  id=$(. /etc/os-release && echo "${ID:-}")

  case "$id" in
    ubuntu)   DISTRO="ubuntu"  ;;
    debian)   DISTRO="debian"  ;;
    arch)     DISTRO="arch"    ;;
    fedora)   DISTRO="fedora"  ;;
    *)
      log_error "Unsupported distro: '${id}'. Supported: ubuntu, debian, arch, fedora."
      return 1
      ;;
  esac

  export DISTRO
}

# ─── ask_confirm ──────────────────────────────────────────────────────────────
# Prompts user for y/n confirmation via /dev/tty.
# Returns 0 for yes, 1 for no.
# Usage: ask_confirm "Continue?" && do_something
ask_confirm() {
  local prompt="${1:-Continue?}"
  local answer
  printf '%s [y/N] ' "$prompt" >/dev/tty
  read -r answer </dev/tty
  case "$answer" in
    [yYsS]) return 0 ;;
    *)      return 1 ;;
  esac
}

# ─── ask_user ─────────────────────────────────────────────────────────────────
# Prompts user for text input via /dev/tty.
# Assigns result to the variable named by $2.
# Usage: ask_user "Your name" GIT_USER_NAME
ask_user() {
  local prompt="$1"
  local varname="$2"
  local value

  # If running inside _run_installer's pipe, sync with the filter before
  # showing the prompt — otherwise the filter's \r\033[2K will overwrite it.
  if [[ -n "${_DOTFILES_SYNC:-}" ]]; then
    echo "__SYNC__"          # tell filter to signal when it has caught up
    local _t=0
    while [[ ! -s "$_DOTFILES_SYNC" ]]; do
      sleep 0.02
      (( _t++ ))
      [[ $_t -gt 25 ]] && break   # 500 ms timeout — don't hang forever
    done
    > "$_DOTFILES_SYNC"      # reset for the next sync
  fi

  printf '\r\033[2K%s: ' "$prompt" >/dev/tty
  read -r value </dev/tty
  printf -v "$varname" '%s' "$value"
}

# ─── parse_manifest ───────────────────────────────────────────────────────────
# Parses manifest.json and populates global arrays:
#   TOOL_IDS       — ordered array of all tool IDs
#   TOOL_NAME[]    — display name per tool
#   TOOL_DEPS[]    — space-separated dependency IDs per tool
#   TOOL_INSTALLER[] — path to installer script per tool
#   TOOL_REQUIRED[] — "true" or "false" per tool
#
# Usage: parse_manifest "$DOTFILES_DIR/manifest.json"
parse_manifest() {
  local manifest_path="$1"

  if [[ ! -f "$manifest_path" ]]; then
    log_error "manifest.json not found: $manifest_path"
    return 1
  fi

  declare -gA TOOL_NAME
  declare -gA TOOL_DEPS
  declare -gA TOOL_INSTALLER
  declare -gA TOOL_REQUIRED
  declare -gA TOOL_CATEGORY
  declare -ga TOOL_IDS

  if check_command python3; then
    _parse_manifest_python "$manifest_path"
  else
    log_warn "python3 not found, using awk fallback for manifest parsing"
    _parse_manifest_awk "$manifest_path"
  fi
}

_parse_manifest_python() {
  local manifest_path="$1"

  local output
  output=$(python3 - "$manifest_path" <<'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    data = json.load(f)

for tool_id, tool in data["tools"].items():
    deps = " ".join(tool.get("dependencies", []))
    required = "true" if tool.get("required", False) else "false"
    # Print as shell assignments, one tool per block
    print(f"TOOL_NAME[{tool_id}]={json.dumps(tool['name'])}")
    print(f"TOOL_DEPS[{tool_id}]={json.dumps(deps)}")
    print(f"TOOL_INSTALLER[{tool_id}]={json.dumps(tool['installer'])}")
    print(f"TOOL_REQUIRED[{tool_id}]={json.dumps(required)}")
    print(f"TOOL_CATEGORY[{tool_id}]={json.dumps(tool.get('category','other'))}")
    print(f"TOOL_IDS+=({json.dumps(tool_id)})")
PYEOF
)

  TOOL_IDS=()
  eval "$output"
}

_parse_manifest_awk() {
  local manifest_path="$1"
  # Minimal awk parser — handles simple single-line JSON values
  # Limitations: doesn't handle multi-line arrays well; sufficient for MVP manifest
  local current_id=""
  TOOL_IDS=()

  while IFS= read -r line; do
    # Match tool ID key: "toolid": {
    if [[ "$line" =~ ^[[:space:]]*\"([a-z_]+)\":[[:space:]]*\{ ]]; then
      current_id="${BASH_REMATCH[1]}"
      [[ "$current_id" == "tools" ]] && current_id="" && continue
      TOOL_IDS+=("$current_id")
    fi

    [[ -z "$current_id" ]] && continue

    # Match "name": "value"
    if [[ "$line" =~ \"name\":[[:space:]]*\"([^\"]+)\" ]]; then
      TOOL_NAME[$current_id]="${BASH_REMATCH[1]}"
    fi

    # Match "installer": "value"
    if [[ "$line" =~ \"installer\":[[:space:]]*\"([^\"]+)\" ]]; then
      TOOL_INSTALLER[$current_id]="${BASH_REMATCH[1]}"
    fi

    # Match "required": true/false
    if [[ "$line" =~ \"required\":[[:space:]]*(true|false) ]]; then
      TOOL_REQUIRED[$current_id]="${BASH_REMATCH[1]}"
    fi

    # Match "category": "value"
    if [[ "$line" =~ \"category\":[[:space:]]*\"([^\"]+)\" ]]; then
      TOOL_CATEGORY[$current_id]="${BASH_REMATCH[1]}"
    fi

    # Match dependencies array (single line: "dependencies": ["base"])
    if [[ "$line" =~ \"dependencies\":[[:space:]]*\[([^\]]*)\] ]]; then
      local raw="${BASH_REMATCH[1]}"
      # Strip quotes and commas → space-separated
      local deps
      deps=$(echo "$raw" | tr -d '"' | tr ',' ' ' | xargs)
      TOOL_DEPS[$current_id]="$deps"
    fi
  done < "$manifest_path"
}

# ─── topological_sort ─────────────────────────────────────────────────────────
# Sorts a space-separated list of tool IDs respecting dependencies from TOOL_DEPS[].
# Requires: TOOL_DEPS[] array populated by parse_manifest.
# Outputs sorted list (space-separated) to stdout.
# Returns 1 if circular dependency detected.
#
# Usage: ordered=$(topological_sort "git base zsh")
topological_sort() {
  local tools="$1"
  local tsort_input=""
  local tool dep

  for tool in $tools; do
    local deps="${TOOL_DEPS[$tool]:-}"
    if [[ -z "$deps" ]]; then
      # No dependencies — add self-edge so tsort includes it
      tsort_input+="${tool} ${tool}"$'\n'
    else
      for dep in $deps; do
        tsort_input+="${dep} ${tool}"$'\n'
      done
    fi
  done

  local sorted
  sorted=$(echo "$tsort_input" | tsort 2>&1) || {
    log_error "Circular dependency detected in tool graph"
    return 1
  }

  # Filter to only include tools that were in the input list
  local result=()
  for tool in $sorted; do
    if [[ " $tools " == *" $tool "* ]]; then
      result+=("$tool")
    fi
  done

  echo "${result[*]}"
}
