# core/zsh/functions.zsh
# ──────────────────────────────────────────────────────────────────────────────
# Cross-OS shell functions. Pure POSIX-ish where possible so they behave the
# same on macOS zsh, Linux zsh, and Alpine's busybox-adjacent environment.
# Nothing OS-specific or offensive here — those live in the OS / Kali repos.
# ──────────────────────────────────────────────────────────────────────────────

# mkcd — make a directory and cd into it
mkcd() { mkdir -p -- "$1" && cd -- "$1"; }

# up — climb N directories (up 3 == cd ../../..)
up() {
  local n="${1:-1}" p=""
  while ((n-- > 0)); do p="../$p"; done
  cd "$p" || return
}

# extract — one command for any archive
extract() {
  [[ -f "$1" ]] || { echo "extract: '$1' is not a file" >&2; return 1; }
  case "$1" in
    *.tar.bz2|*.tbz2) tar xjf "$1" ;;
    *.tar.gz|*.tgz)   tar xzf "$1" ;;
    *.tar.xz)         tar xJf "$1" ;;
    *.tar)            tar xf  "$1" ;;
    *.bz2)            bunzip2 "$1" ;;
    *.gz)             gunzip  "$1" ;;
    *.zip)            unzip   "$1" ;;
    *.7z)             7z x    "$1" ;;
    *.rar)            unrar x "$1" ;;
    *)                echo "extract: unknown format '$1'" >&2; return 1 ;;
  esac
}

# fcd — fuzzy-cd into any subdirectory (needs fzf + fd, degrades to find)
fcd() {
  local dir
  if [[ -n ${HAVE_FZF:-} && -n ${HAVE_FD:-} ]]; then
    dir=$("$FD_BIN" --type d --hidden --exclude .git | fzf) && cd "$dir"
  else
    dir=$(find . -type d -not -path '*/.git/*' 2>/dev/null | fzf) && cd "$dir"
  fi
}

# please — re-run the last command with sudo
please() { sudo $(fc -ln -1); }

# mkbak — timestamped backup of a file before you edit it
mkbak() { cp -- "$1" "$1.$(date +%Y%m%d-%H%M%S).bak"; }
