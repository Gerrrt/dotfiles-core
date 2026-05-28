# core/zsh/aliases.zsh
# ──────────────────────────────────────────────────────────────────────────────
# Aliases for the modern CLI stack. Every alias is GUARDED by a HAVE_* flag from
# tools.zsh, so on a bare box (fresh server, rescue shell) you transparently get
# the classic command instead of "command not found". Load AFTER tools.zsh.
# ──────────────────────────────────────────────────────────────────────────────

# ── ls -> eza ─────────────────────────────────────────────────────────────────
if [[ -n ${HAVE_EZA:-} ]]; then
  alias ls='eza --group-directories-first --icons=auto'
  alias ll='eza -lah --group-directories-first --icons=auto --git'
  alias la='eza -a  --group-directories-first --icons=auto'
  alias lt='eza --tree --level=2 --icons=auto'
  alias llt='eza --tree --level=3 -l --icons=auto'
else
  alias ll='ls -lah'
  alias la='ls -A'
fi

# ── cat -> bat (resolved name from tools.zsh) ────────────────────────────────
if [[ -n ${HAVE_BAT:-} ]]; then
  alias cat="$BAT_BIN --paging=never"
  alias catp="$BAT_BIN"                 # paged, full bat
  export BAT_THEME="ansi"               # respects terminal palette
  export MANPAGER="sh -c 'col -bx | $BAT_BIN -l man -p'"
fi

# ── find -> fd ────────────────────────────────────────────────────────────────
[[ -n ${HAVE_FD:-} ]] && alias fd="$FD_BIN"

# ── grep -> ripgrep (keep grep itself POSIX for scripts) ──────────────────────
[[ -n ${HAVE_RG:-} ]] && alias rg='rg --smart-case'

# ── cd -> zoxide (z), interactive jump (zi) ──────────────────────────────────
if [[ -n ${HAVE_ZOXIDE:-} ]]; then
  alias cd='z'
  alias cdi='zi'
fi

# ── disk / process / monitor ──────────────────────────────────────────────────
[[ -n ${HAVE_DUST:-}  ]] && alias du='dust'
[[ -n ${HAVE_PROCS:-} ]] && alias ps='procs'
[[ -n ${HAVE_BTOP:-}  ]] && alias top='btop' && alias htop='btop'

# ── file manager ──────────────────────────────────────────────────────────────
[[ -n ${HAVE_YAZI:-} ]] && alias fm='yazi'

# ── git quality-of-life (delta is wired in git/gitconfig, not here) ──────────
alias g='git'
alias gs='git status -sb'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate -20'
alias lg='lazygit'

# ── safety nets (POSIX, intentionally NOT modernized) ────────────────────────
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias mkdir='mkdir -p'

# ── network conveniences (stay in Core; anything engagement-flavored -> Kali)─
alias myip='curl -fsS https://ifconfig.me 2>/dev/null && echo'
alias ports='ss -tulpn 2>/dev/null || netstat -tulpn'
alias serve='python3 -m http.server'
