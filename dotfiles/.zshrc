# .zshrc — Zsh configuration

export ZSH="${HOME}/.oh-my-zsh"

ZSH_THEME="robbyrussell"

plugins=(
  git
  z
  sudo
  copypath
  dirhistory
)

[[ -f "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

# ─── PATH ─────────────────────────────────────────────────────────────────────
export PATH="${HOME}/.local/bin:${HOME}/bin:${PATH}"
[[ -d "${HOME}/.fzf/bin" ]] && export PATH="${HOME}/.fzf/bin:${PATH}"

# ─── Aliases ──────────────────────────────────────────────────────────────────
alias ll='ls -lAh'
alias la='ls -A'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias df='df -h'
alias du='du -sh'

# ─── fzf ──────────────────────────────────────────────────────────────────────
[[ -f "${HOME}/.fzf.zsh" ]] && source "${HOME}/.fzf.zsh"

# ─── Editor ───────────────────────────────────────────────────────────────────
if command -v nvim &>/dev/null; then
  export EDITOR="nvim"
  export VISUAL="nvim"
elif command -v vim &>/dev/null; then
  export EDITOR="vim"
  export VISUAL="vim"
fi
