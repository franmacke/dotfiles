#!/usr/bin/env bash
# Installer: git
# Installs git and configures user identity interactively

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/src/logger.sh"
source "${SCRIPT_DIR}/src/utils.sh"

install_git() {
  log_info "Installing Git..."

  if command -v git &>/dev/null; then
    log_success "Git already installed: $(git --version)"
  else
    case "${DISTRO}" in
      ubuntu|debian)
        sudo apt-get install -y git
        ;;
      arch)
        sudo pacman -S --noconfirm --needed git
        ;;
      fedora)
        sudo dnf install -y git
        ;;
      *)
        log_error "Unsupported distro: ${DISTRO}"
        return 1
        ;;
    esac
    log_success "Git installed: $(git --version)"
  fi

  # Configure user identity if not already set
  local current_name
  current_name=$(git config --global user.name 2>/dev/null || true)

  if [[ -z "$current_name" ]]; then
    echo ""
    log_info "Git identity not configured. Let's set it up."

    local git_name git_email
    ask_user "Your full name (for git commits)" git_name
    ask_user "Your email address (for git commits)" git_email

    git config --global user.name "$git_name"
    git config --global user.email "$git_email"
    log_success "Git identity configured: ${git_name} <${git_email}>"
  else
    log_info "Git identity already set: ${current_name} <$(git config --global user.email 2>/dev/null || echo 'no email')>"
  fi
}

install_git
