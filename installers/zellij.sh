#!/usr/bin/env bash
# Installer: zellij

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/src/logger.sh"

install_zellij() {
  log_info "Installing Zellij..."

  if command -v zellij &>/dev/null; then
    log_success "Zellij already installed: $(zellij --version)"
    return 0
  fi

  case "${DISTRO}" in
    ubuntu|debian)
      # No official apt package — install via cargo or prebuilt binary
      local version
      version=$(curl -fsSL https://api.github.com/repos/zellij-org/zellij/releases/latest \
        | grep '"tag_name"' | head -1 | sed 's/.*"v\([^"]*\)".*/\1/')
      local arch
      arch=$(uname -m)
      local tarball="zellij-${arch}-unknown-linux-musl.tar.gz"

      curl -fsSL "https://github.com/zellij-org/zellij/releases/download/v${version}/${tarball}" \
        | tar -xz -C /tmp
      sudo install -m 0755 /tmp/zellij /usr/local/bin/zellij
      rm -f /tmp/zellij
      ;;
    arch)
      sudo pacman -S --noconfirm --needed zellij
      ;;
    fedora)
      sudo dnf install -y zellij
      ;;
    *)
      log_error "Unsupported distro: ${DISTRO}"
      return 1
      ;;
  esac

  log_success "Zellij installed: $(zellij --version)"
}

install_zellij
