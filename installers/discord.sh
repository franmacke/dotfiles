#!/usr/bin/env bash
# Installer: discord

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/src/logger.sh"

install_discord() {
  log_info "Installing Discord..."

  if command -v discord &>/dev/null || [[ -x /opt/discord/Discord ]]; then
    log_success "Discord already installed"
    return 0
  fi

  case "${DISTRO}" in
    ubuntu|debian)
      local deb="/tmp/discord.deb"
      log_info "Downloading Discord .deb..."
      curl -fsSL "https://discord.com/api/download?platform=linux&format=deb" -o "$deb"
      sudo dpkg -i "$deb" || sudo apt-get install -f -y
      rm -f "$deb"
      ;;
    arch)
      sudo pacman -S --noconfirm --needed discord
      ;;
    fedora)
      _install_discord_targz
      ;;
    *)
      log_error "Unsupported distro: ${DISTRO}"
      return 1
      ;;
  esac

  log_success "Discord installed"
}

_install_discord_targz() {
  local tarball="/tmp/discord.tar.gz"
  local install_dir="/opt/discord"

  log_info "Downloading Discord tar.gz..."
  curl -fsSL "https://discord.com/api/download?platform=linux&format=tar.gz" -o "$tarball"

  sudo mkdir -p "$install_dir"
  sudo tar -xz -C /opt -f "$tarball"
  # Discord extracts as /opt/Discord — normalize to /opt/discord
  if [[ -d /opt/Discord ]] && [[ ! -d "$install_dir" ]]; then
    sudo mv /opt/Discord "$install_dir"
  fi
  rm -f "$tarball"

  # Symlink binary
  sudo ln -sf "${install_dir}/Discord" /usr/local/bin/discord

  # Desktop entry
  sudo bash -c "cat > /usr/share/applications/discord.desktop" <<EOF
[Desktop Entry]
Name=Discord
Comment=All-in-one voice and text chat
Exec=/opt/discord/Discord
Icon=/opt/discord/discord.png
Terminal=false
Type=Application
Categories=Network;InstantMessaging;
StartupWMClass=discord
EOF
}

install_discord
