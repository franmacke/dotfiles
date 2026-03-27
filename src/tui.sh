#!/usr/bin/env bash
# tui.sh — Interactive tool selection menu, grouped by category
# Requires: TOOL_IDS, TOOL_NAME[], TOOL_DEPS[], TOOL_REQUIRED[], TOOL_CATEGORY[]
# Output: space-separated tool IDs to stdout
# Exit 0: confirmed; Exit 1: cancelled

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logger.sh"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/utils.sh"

parse_manifest "${DOTFILES_DIR}/manifest.json"

# ─── Category display labels (manifest category → user-facing group name) ─────
declare -A _CAT_LABEL
_CAT_LABEL[system]="System"
_CAT_LABEL[vcs]="Dev"
_CAT_LABEL[runtime]="Dev"
_CAT_LABEL[devops]="Dev"
_CAT_LABEL[shell]="Terminal"
_CAT_LABEL[editor]="Editors"
_CAT_LABEL[terminal]="Terminal"
_CAT_LABEL[tools]="Tools"
_CAT_LABEL[apps]="Apps"

_cat_label_for() {
  local cat="${TOOL_CATEGORY[$1]:-other}"
  echo "${_CAT_LABEL[$cat]:-${cat^}}"
}

# ─── Separate required vs optional tools ──────────────────────────────────────
_required_tools=()
_optional_tools=()
for _id in "${TOOL_IDS[@]}"; do
  if [[ "${TOOL_REQUIRED[$_id]:-false}" == "true" ]]; then
    _required_tools+=("$_id")
  else
    _optional_tools+=("$_id")
  fi
done

# Sort optional tools by category label then by name
_sorted_optional=()
while IFS=$'\t' read -r _ id; do
  _sorted_optional+=("$id")
done < <(
  for id in "${_optional_tools[@]}"; do
    printf '%s\t%s\n' "$(_cat_label_for "$id")" "$id"
  done | sort -t$'\t' -k1,1 -k2,2
)

# ─── fzf mode ─────────────────────────────────────────────────────────────────
_tui_fzf() {
  local lines=()
  for id in "${_sorted_optional[@]}"; do
    local name="${TOOL_NAME[$id]:-$id}"
    local deps="${TOOL_DEPS[$id]:-}"
    local label
    label=$(_cat_label_for "$id")
    local dep_str=""
    [[ -n "$deps" ]] && dep_str="  · deps: ${deps}"
    # Format: id TAB category TAB "Name  dep_str"
    lines+=("${id}"$'\t'"${label}"$'\t'"${name}${dep_str}")
  done

  local selected
  selected=$(printf '%s\n' "${lines[@]}" \
    | fzf --multi \
          --delimiter=$'\t' \
          --with-nth=2,3 \
          --prompt="Select tools (TAB=toggle, ENTER=confirm, ESC=cancel): " \
          --height=~80% \
          --layout=reverse \
          --border \
          --header="Always installed: $(IFS=', '; echo "${_required_tools[*]}")" \
    | awk -F'\t' '{print $1}') || {
      log_error "Selection cancelled."
      exit 1
    }

  local result=("${_required_tools[@]}")
  for id in $selected; do
    result+=("$id")
  done
  echo "${result[*]}"
}

# ─── Pure bash fallback mode ──────────────────────────────────────────────────
_tui_bash() {
  declare -A _selected
  for id in "${_required_tools[@]}"; do
    _selected[$id]=1
  done

  # Build per-tool category label map
  declare -A _labels
  for id in "${_sorted_optional[@]}"; do
    _labels[$id]=$(_cat_label_for "$id")
  done

  local tools=("${_sorted_optional[@]}")
  local cursor=0
  local total=${#tools[@]}

  local old_stty
  old_stty=$(stty -g </dev/tty)
  stty -echo -icanon </dev/tty

  _render() {
    tput clear >/dev/tty 2>/dev/null || printf '\033[2J\033[H' >/dev/tty

    printf '\n  ╔══════════════════════════════════════════════════════╗\n' >/dev/tty
    printf '  ║           Dotfiles Installer — Select Tools          ║\n' >/dev/tty
    printf '  ╚══════════════════════════════════════════════════════╝\n' >/dev/tty
    printf '\n  Always installed: %s\n' "$(IFS=', '; echo "${_required_tools[*]}")" >/dev/tty

    local prev_label=""
    local i=0
    for id in "${tools[@]}"; do
      local label="${_labels[$id]}"
      # Print category header when group changes
      if [[ "$label" != "$prev_label" ]]; then
        printf '\n  \033[1;33m── %s\033[0m\n' "$label" >/dev/tty
        prev_label="$label"
      fi

      local name="${TOOL_NAME[$id]:-$id}"
      local deps="${TOOL_DEPS[$id]:-}"
      local dep_str=""
      [[ -n "$deps" ]] && dep_str="  · ${deps}"

      local checkbox="[ ]"
      [[ -n "${_selected[$id]+x}" ]] && checkbox="[✓]"

      local pointer="  "
      [[ $i -eq $cursor ]] && pointer="\033[1m> "

      printf "  ${pointer}%s \033[0m%-30s\033[2m%s\033[0m\n" \
        "$checkbox" "$name" "$dep_str" >/dev/tty
      (( i++ ))
    done

    printf '\n  \033[2mj/↓ down  k/↑ up  SPACE toggle  ENTER confirm  q cancel\033[0m\n' >/dev/tty
  }

  while true; do
    _render

    local key
    IFS= read -rsn1 key </dev/tty

    if [[ "$key" == $'\x1b' ]]; then
      IFS= read -rsn2 -t 0.1 key </dev/tty || key=""
      case "$key" in
        '[A') key='k' ;;
        '[B') key='j' ;;
        *)    key=''  ;;
      esac
    fi

    case "$key" in
      j) (( cursor < total - 1 )) && (( cursor++ )) ;;
      k) (( cursor > 0 )) && (( cursor-- )) ;;
      ' ')
        local id="${tools[$cursor]}"
        if [[ -n "${_selected[$id]+x}" ]]; then
          unset '_selected[$id]'
        else
          _selected[$id]=1
        fi
        ;;
      '') # Enter
        stty "$old_stty" </dev/tty
        break
        ;;
      q|Q)
        stty "$old_stty" </dev/tty
        log_error "Installation cancelled by user."
        exit 1
        ;;
    esac
  done

  local result=("${_required_tools[@]}")
  for id in "${tools[@]}"; do
    [[ -n "${_selected[$id]+x}" ]] && result+=("$id")
  done
  echo "${result[*]}"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
if check_command fzf; then
  _tui_fzf
else
  _tui_bash
fi
