#!/usr/bin/env bash
# Installer: steam

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/src/logger.sh"

install_steam() {
  log_info "Installing Steam..."

  if command -v steam &>/dev/null; then
    log_success "Steam already installed"
    return 0
  fi

  case "${DISTRO}" in
    ubuntu|debian)
      # Steam requires 32-bit (i386) support
      sudo dpkg --add-architecture i386
      sudo apt-get update -qq
      sudo apt-get install -y steam
      ;;
    arch)
      # Requires multilib repo in /etc/pacman.conf
      if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
        log_info "Enabling multilib repo..."
        sudo sed -i '/^#\[multilib\]/{N;s/#\[multilib\]\n#Include/\[multilib\]\nInclude/}' \
          /etc/pacman.conf
        sudo pacman -Sy --noconfirm
      fi
      sudo pacman -S --noconfirm --needed steam
      ;;
    fedora)
      # Requires RPM Fusion repos
      sudo dnf install -y \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
      sudo dnf install -y steam
      ;;
    *)
      log_error "Unsupported distro: ${DISTRO}"
      return 1
      ;;
  esac

  log_success "Steam installed"
}

install_steam
