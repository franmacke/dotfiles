#!/usr/bin/env bash
# Installer: nodejs

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/src/logger.sh"

install_nodejs() {
  log_info "Installing Node.js..."

  if command -v node &>/dev/null; then
    log_success "Node.js already installed: $(node --version)"
    return 0
  fi

  case "${DISTRO}" in
    ubuntu|debian)
      # NodeSource LTS
      curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
      sudo apt-get install -y nodejs
      ;;
    arch)
      sudo pacman -S --noconfirm --needed nodejs npm
      ;;
    fedora)
      sudo dnf install -y nodejs npm
      ;;
    *)
      log_error "Unsupported distro: ${DISTRO}"
      return 1
      ;;
  esac

  log_success "Node.js installed: $(node --version) / npm $(npm --version)"
}

install_nodejs
