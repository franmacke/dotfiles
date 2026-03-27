#!/usr/bin/env bash
# Installer: fzf

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/src/logger.sh"

install_fzf() {
  log_info "Installing fzf..."

  if command -v fzf &>/dev/null; then
    log_success "fzf already installed: $(fzf --version)"
    return 0
  fi

  # Use git install method — distro-agnostic and always latest stable
  if [[ -d "${HOME}/.fzf" ]]; then
    log_info "Updating existing fzf repo..."
    git -C "${HOME}/.fzf" pull --quiet
  else
    git clone --depth 1 https://github.com/junegunn/fzf.git "${HOME}/.fzf"
  fi

  "${HOME}/.fzf/install" --all --no-bash --no-fish --no-zsh

  # Add to PATH for current session
  export PATH="${HOME}/.fzf/bin:${PATH}"

  log_success "fzf installed: $(fzf --version)"
  log_info "fzf shell integration will be active after reloading your shell"
}

install_fzf
