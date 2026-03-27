#!/usr/bin/env bash
# Installer: ripgrep

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/src/logger.sh"

install_ripgrep() {
  log_info "Installing ripgrep..."

  if command -v rg &>/dev/null; then
    log_success "ripgrep already installed: $(rg --version | head -1)"
    return 0
  fi

  case "${DISTRO}" in
    ubuntu|debian)
      sudo apt-get install -y ripgrep
      ;;
    arch)
      sudo pacman -S --noconfirm --needed ripgrep
      ;;
    fedora)
      sudo dnf install -y ripgrep
      ;;
    *)
      log_error "Unsupported distro: ${DISTRO}"
      return 1
      ;;
  esac

  log_success "ripgrep installed: $(rg --version | head -1)"
}

install_ripgrep
