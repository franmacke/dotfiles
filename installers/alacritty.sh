#!/usr/bin/env bash
# Installer: alacritty

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/src/logger.sh"

install_alacritty() {
  log_info "Installing Alacritty..."

  if command -v alacritty &>/dev/null; then
    log_success "Alacritty already installed: $(alacritty --version)"
    return 0
  fi

  case "${DISTRO}" in
    ubuntu|debian)
      # Official PPA
      sudo add-apt-repository -y ppa:aslatter/ppa
      sudo apt-get update -qq
      sudo apt-get install -y alacritty
      ;;
    arch)
      sudo pacman -S --noconfirm --needed alacritty
      ;;
    fedora)
      sudo dnf install -y alacritty
      ;;
    *)
      log_error "Unsupported distro: ${DISTRO}"
      return 1
      ;;
  esac

  log_success "Alacritty installed: $(alacritty --version)"
}

install_alacritty
