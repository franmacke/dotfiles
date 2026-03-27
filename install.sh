#!/usr/bin/env bash
# install.sh — Bootstrap entry point
# Usage: curl -fsSL <url> | bash
#        ./install.sh

set -euo pipefail

DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/franmacke/dotfiles}"
WORK_DIR=""

# ─── cleanup ──────────────────────────────────────────────────────────────────
cleanup() {
  if [[ -n "$WORK_DIR" && -d "$WORK_DIR" && "$WORK_DIR" != "${DOTFILES_DIR:-}" ]]; then
    rm -rf "$WORK_DIR"
  fi
}
trap cleanup EXIT

# ─── detect_distro_early ──────────────────────────────────────────────────────
# Standalone distro detection (libs not sourced yet).
detect_distro_early() {
  if [[ ! -f /etc/os-release ]]; then
    echo "[ERROR] Cannot detect distro: /etc/os-release not found" >&2
    exit 1
  fi

  local id
  id=$(. /etc/os-release && echo "${ID:-}")

  case "$id" in
    ubuntu)  DISTRO="ubuntu"  ;;
    debian)  DISTRO="debian"  ;;
    arch)    DISTRO="arch"    ;;
    fedora)  DISTRO="fedora"  ;;
    *)
      echo "[ERROR] Unsupported distro: '${id}'. Supported: ubuntu, debian, arch, fedora." >&2
      exit 1
      ;;
  esac

  export DISTRO
  echo "[INFO] Detected distro: ${DISTRO}"
}

# ─── download_repo ────────────────────────────────────────────────────────────
download_repo() {
  # If DOTFILES_DIR is already set and valid, use it directly (local re-run)
  if [[ -n "${DOTFILES_DIR:-}" && -f "${DOTFILES_DIR}/manifest.json" ]]; then
    echo "[INFO] Using existing dotfiles directory: ${DOTFILES_DIR}"
    return 0
  fi

  # Check if we're already running from the repo (./install.sh case)
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -f "${script_dir}/manifest.json" ]]; then
    DOTFILES_DIR="$script_dir"
    export DOTFILES_DIR
    echo "[INFO] Running from repo directory: ${DOTFILES_DIR}"
    return 0
  fi

  # Need to download
  WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-XXXXXX")
  echo "[INFO] Downloading dotfiles to ${WORK_DIR}..."

  if command -v git &>/dev/null; then
    git clone --depth=1 "${DOTFILES_REPO}" "${WORK_DIR}" \
      || { echo "[ERROR] git clone failed" >&2; exit 1; }
  elif command -v curl &>/dev/null; then
    local tarball="${DOTFILES_REPO}/archive/refs/heads/main.tar.gz"
    curl -fsSL "$tarball" | tar -xz -C "$WORK_DIR" --strip-components=1 \
      || { echo "[ERROR] curl download failed" >&2; exit 1; }
  elif command -v wget &>/dev/null; then
    local tarball="${DOTFILES_REPO}/archive/refs/heads/main.tar.gz"
    wget -qO- "$tarball" | tar -xz -C "$WORK_DIR" --strip-components=1 \
      || { echo "[ERROR] wget download failed" >&2; exit 1; }
  else
    echo "[ERROR] git, curl, and wget are all unavailable. Cannot download dotfiles." >&2
    exit 1
  fi

  DOTFILES_DIR="$WORK_DIR"
  export DOTFILES_DIR
}

# ─── main ─────────────────────────────────────────────────────────────────────
main() {
  echo ""
  echo "[INFO] Dotfiles Installer — Bootstrap"
  echo ""

  detect_distro_early
  download_repo

  local orchestrator="${DOTFILES_DIR}/src/orchestrator.sh"
  if [[ ! -f "$orchestrator" ]]; then
    echo "[ERROR] orchestrator.sh not found: ${orchestrator}" >&2
    exit 1
  fi

  exec bash "$orchestrator" "$@"
}

main "$@"
