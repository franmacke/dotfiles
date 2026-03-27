#!/usr/bin/env bash
# Installer: appimage
# Installs the 'appimage' CLI tool from https://github.com/franmacke/appimage

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/src/logger.sh"

install_appimage() {
  log_info "Installing appimage CLI..."

  if [[ -x "${HOME}/.local/bin/appimage" ]]; then
    log_success "appimage already installed: ${HOME}/.local/bin/appimage"
    return 0
  fi

  local install_url="https://raw.githubusercontent.com/franmacke/appimage/main/install.sh"

  if command -v curl &>/dev/null; then
    bash <(curl -fsSL "$install_url")
  elif command -v wget &>/dev/null; then
    bash <(wget -qO- "$install_url")
  else
    log_error "curl or wget is required to install appimage"
    return 1
  fi

  log_success "appimage CLI installed: ${HOME}/.local/bin/appimage"
}

install_appimage
