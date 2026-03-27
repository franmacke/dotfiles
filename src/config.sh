#!/usr/bin/env bash
# config.sh — Global configuration variables
# Source this file: source src/config.sh

# Distro detected by detect_distro() or install.sh bootstrap
DISTRO="${DISTRO:-}"

# Root directory of the dotfiles repository
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Where existing dotfiles are backed up before being overwritten
HOME_BACKUP_DIR="${HOME_BACKUP_DIR:-${HOME}/.dotfiles-backup}"

# Path to the installation record file
DOTFILES_INSTALLED_FILE="${DOTFILES_INSTALLED_FILE:-${HOME}/.dotfiles-installed}"

# Version — read from VERSION file in repo root
_version_file="${DOTFILES_DIR}/VERSION"
if [[ -f "$_version_file" ]]; then
  DOTFILES_VERSION="${DOTFILES_VERSION:-$(cat "$_version_file")}"
else
  DOTFILES_VERSION="${DOTFILES_VERSION:-0.0.0}"
fi
unset _version_file
