#!/usr/bin/env bash
# Installer: neovim

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/src/logger.sh"

install_neovim() {
  log_info "Installing Neovim..."

  if ! command -v nvim &>/dev/null; then
    case "${DISTRO}" in
      ubuntu|debian)
        # Use stable PPA for up-to-date version
        sudo add-apt-repository -y ppa:neovim-ppa/stable
        sudo apt-get update -qq
        sudo apt-get install -y neovim
        ;;
      arch)
        sudo pacman -S --noconfirm --needed neovim
        ;;
      fedora)
        sudo dnf install -y neovim
        ;;
      *)
        log_error "Unsupported distro: ${DISTRO}"
        return 1
        ;;
    esac
    log_success "Neovim installed: $(nvim --version | head -1)"
  else
    log_success "Neovim already installed: $(nvim --version | head -1)"
  fi

  # Install vim-plug
  local plug_path="${HOME}/.local/share/nvim/site/autoload/plug.vim"
  if [[ ! -f "$plug_path" ]]; then
    log_info "Installing vim-plug..."
    curl -fLo "$plug_path" --create-dirs \
      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    log_success "vim-plug installed"
  else
    log_success "vim-plug already installed"
  fi
}

install_neovim
