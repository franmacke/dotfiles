#!/usr/bin/env bash
# logger.sh — Logging functions with ANSI color support
# Source this file: source src/logger.sh

# Detect if output is a TTY; if not, suppress color codes.
# DOTFILES_COLOR=1 forces colors even when stdout is piped (used by run_installer).
_logger_is_tty() {
  [ -t 1 ] || [[ "${DOTFILES_COLOR:-0}" == "1" ]]
}

_logger_is_tty_stderr() {
  [ -t 2 ] || [[ "${DOTFILES_COLOR:-0}" == "1" ]]
}

# ANSI color codes
_CLR_RESET='\033[0m'
_CLR_BLUE='\033[0;34m'
_CLR_GREEN='\033[0;32m'
_CLR_RED='\033[0;31m'
_CLR_YELLOW='\033[0;33m'

log_info() {
  local msg="$*"
  if _logger_is_tty; then
    printf "${_CLR_BLUE}[INFO]${_CLR_RESET} %s\n" "$msg"
  else
    printf '[INFO] %s\n' "$msg"
  fi
}

log_success() {
  local msg="$*"
  if _logger_is_tty; then
    printf "${_CLR_GREEN}[✓]${_CLR_RESET} %s\n" "$msg"
  else
    printf '[OK] %s\n' "$msg"
  fi
}

log_error() {
  local msg="$*"
  if _logger_is_tty_stderr; then
    printf "${_CLR_RED}[ERROR]${_CLR_RESET} %s\n" "$msg" >&2
  else
    printf '[ERROR] %s\n' "$msg" >&2
  fi
}

log_warn() {
  local msg="$*"
  if _logger_is_tty; then
    printf "${_CLR_YELLOW}[WARN]${_CLR_RESET} %s\n" "$msg"
  else
    printf '[WARN] %s\n' "$msg"
  fi
}
