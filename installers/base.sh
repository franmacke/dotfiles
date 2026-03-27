#!/usr/bin/env bash
# Installer: base
# Installs essential build tools: build-essential/base-devel, curl, wget

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/src/logger.sh"

install_base() {
  log_info "Installing base system tools..."

  case "${DISTRO}" in
    ubuntu|debian)
      log_info "Updating package lists..."
      sudo apt-get update -qq

      log_info "Installing build-essential, curl, wget..."
      sudo apt-get install -y \
        build-essential \
        curl \
        wget \
        ca-certificates \
        gnupg \
        lsb-release \
        software-properties-common \
        apt-transport-https
      ;;
    arch)
      log_info "Updating package database..."
      sudo pacman -Sy --noconfirm

      log_info "Installing base-devel, curl, wget..."
      sudo pacman -S --noconfirm --needed \
        base-devel \
        curl \
        wget \
        ca-certificates \
        gnupg
      ;;
    fedora)
      log_info "Installing Development Tools, curl, wget..."
      sudo dnf groupinstall -y "Development Tools"
      sudo dnf install -y \
        curl \
        wget \
        ca-certificates \
        gnupg2
      ;;
    *)
      log_error "Unsupported distro: ${DISTRO}"
      return 1
      ;;
  esac

  log_success "Base system tools installed"
}

install_base
