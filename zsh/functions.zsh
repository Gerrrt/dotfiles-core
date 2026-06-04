# core/zsh/functions.zsh
# ──────────────────────────────────────────────────────────────────────────────
# Cross-OS shell functions. Pure POSIX-ish where possible so they behave the
# same on macOS zsh, Linux zsh, and Alpine's busybox-adjacent environment.
# Nothing OS-specific or offensive here — those live in the OS / Kali repos.
# ──────────────────────────────────────────────────────────────────────────────

# mkcd — make a directory and cd into it
mkcd() { mkdir -p -- "$1" && cd -- "$1"; }

# up — climb N directories (up 3 == cd ../../..)
cdup() {
  local n="${1:-1}" p=""
  while ((n-- > 0)); do p="../$p"; done
  cd "$p" || return
}

# extract — one command for any archive
extract() {
  [[ -f "$1" ]] || {
    echo "extract: '$1' is not a file" >&2
    return 1
  }
  case "$1" in
  *.tar.bz2 | *.tbz2) tar xjf "$1" ;;
  *.tar.gz | *.tgz) tar xzf "$1" ;;
  *.tar.xz) tar xJf "$1" ;;
  *.tar) tar xf "$1" ;;
  *.bz2) bunzip2 "$1" ;;
  *.gz) gunzip "$1" ;;
  *.zip) unzip "$1" ;;
  *.7z) 7z x "$1" ;;
  *.rar) unrar x "$1" ;;
  *)
    echo "extract: unknown format '$1'" >&2
    return 1
    ;;
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

# serve — quick HTTP server in the CWD, printing the URLs it's actually reachable
# at (tunnel IP first, then LAN). Replaces the old `serve` alias. Binds all
# interfaces on purpose: this is your ad-hoc file-transfer server. Optional port.
#   serve            # port 8000
#   serve 8080       # port 8080
serve() {
  local port="${1:-8000}" ip
  echo "serving $(pwd) on port ${port}  (Ctrl-C to stop)"
  # tunnel IP (callback address) if a tun/wg interface is up, else LAN, via `ip`
  if command -v ip >/dev/null 2>&1; then
    for i in tun0 tun1 wg0 proton0 tailscale0; do
      ip=$(ip -4 -o addr show "$i" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1)
      [[ -n "$ip" ]] && {
        echo "  → http://${ip}:${port}/   (${i})"
        break
      }
    done
    ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1);exit}}')
    [[ -n "$ip" ]] && echo "  → http://${ip}:${port}/   (lan)"
  fi
  python3 -m http.server "$port"
}
