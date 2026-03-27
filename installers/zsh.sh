#!/usr/bin/env bash
# Installer: zsh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/src/logger.sh"

install_zsh() {
  log_info "Installing Zsh..."

  if ! command -v zsh &>/dev/null; then
    case "${DISTRO}" in
      ubuntu|debian)
        sudo apt-get install -y zsh
        ;;
      arch)
        sudo pacman -S --noconfirm --needed zsh
        ;;
      fedora)
        sudo dnf install -y zsh
        ;;
      *)
        log_error "Unsupported distro: ${DISTRO}"
        return 1
        ;;
    esac
    log_success "Zsh installed: $(zsh --version)"
  else
    log_success "Zsh already installed: $(zsh --version)"
  fi

  # Install Oh My Zsh if not present
  if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
    log_info "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
      "" --unattended
    log_success "Oh My Zsh installed"
  else
    log_success "Oh My Zsh already installed"
  fi

  log_warn "To set Zsh as default shell, run: chsh -s \$(which zsh)"
}

install_zsh
