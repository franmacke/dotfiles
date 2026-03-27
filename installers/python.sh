#!/usr/bin/env bash
# Installer: python

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/src/logger.sh"

install_python() {
  log_info "Installing Python 3..."

  if command -v python3 &>/dev/null; then
    log_success "Python 3 already installed: $(python3 --version)"
    return 0
  fi

  case "${DISTRO}" in
    ubuntu|debian)
      sudo apt-get install -y python3 python3-pip python3-venv
      ;;
    arch)
      sudo pacman -S --noconfirm --needed python python-pip
      ;;
    fedora)
      sudo dnf install -y python3 python3-pip
      ;;
    *)
      log_error "Unsupported distro: ${DISTRO}"
      return 1
      ;;
  esac

  log_success "Python installed: $(python3 --version)"
}

install_python
