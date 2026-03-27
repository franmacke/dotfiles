#!/usr/bin/env bash
# Installer: docker

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/src/logger.sh"

install_docker() {
  log_info "Installing Docker..."

  if command -v docker &>/dev/null; then
    log_success "Docker already installed: $(docker --version)"
    return 0
  fi

  case "${DISTRO}" in
    ubuntu|debian)
      # Official Docker repo
      sudo install -m 0755 -d /etc/apt/keyrings
      curl -fsSL "https://download.docker.com/linux/${DISTRO}/gpg" \
        | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      sudo chmod a+r /etc/apt/keyrings/docker.gpg

      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/${DISTRO} \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

      sudo apt-get update -qq
      sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
      ;;
    arch)
      sudo pacman -S --noconfirm --needed docker docker-compose
      sudo systemctl enable docker
      ;;
    fedora)
      sudo dnf -y install dnf-plugins-core
      sudo dnf config-manager --add-repo \
        https://download.docker.com/linux/fedora/docker-ce.repo
      sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
      sudo systemctl enable docker
      ;;
    *)
      log_error "Unsupported distro: ${DISTRO}"
      return 1
      ;;
  esac

  # Add current user to docker group
  sudo usermod -aG docker "$USER"
  log_success "Docker installed: $(docker --version)"
  log_warn "Log out and back in for docker group membership to take effect"
}

install_docker
