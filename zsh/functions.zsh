# core/zsh/functions.zsh
# ──────────────────────────────────────────────────────────────────────────────
# Cross-OS shell functions. Pure POSIX-ish where possible so they behave the
# same on macOS zsh, Linux zsh, and Alpine's busybox-adjacent environment.
# Nothing OS-specific or offensive here — those live in the OS / Kali repos.
# ──────────────────────────────────────────────────────────────────────────────

# mkcd — make a directory and cd into it
mkcd() {
  [[ -z "$1" ]] && { _core_usage "mkcd <dir>"; return 1; }
  mkdir -p -- "$1" && cd -- "$1"
}

# cdup — climb N directories (cdup 3 == cd ../../..). NOT named `up`: that's the
# package-updater in update.zsh.
cdup() {
  local n="${1:-1}" p=""
  while ((n-- > 0)); do p="../$p"; done
  cd "$p" || return
}

# extract — one command for any archive
extract() {
  [[ -z "$1" ]] && { _core_usage "extract <archive>"; return 1; }
  [[ -f "$1" ]] || {
    _core_err "extract: '$1' is not a file"
    return 1
  }
  # ouch (if installed) handles every format below and more from one binary;
  # the hand-rolled case statement stays as the bare-box / no-ouch fallback.
  [[ -n ${HAVE_OUCH:-} ]] && { ouch decompress "$1"; return; }
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
    _core_err "extract: unknown format '$1'"
    _core_hint "supported: .tar.gz/.tgz .tar.bz2/.tbz2 .tar.xz .tar .gz .bz2 .zip .7z .rar"
    return 1
    ;;
  esac
}

# fcd — fuzzy-cd into any subdirectory (needs fzf + fd, degrades to find)
fcd() {
  _core_have fzf || {
    _core_err "fcd: requires fzf"
    _core_hint "install fzf, then retry"
    return 1
  }
  local dir
  if [[ -n ${HAVE_FZF:-} && -n ${HAVE_FD:-} ]]; then
    dir=$("$FD_BIN" --type d --hidden --exclude .git | fzf) && cd "$dir"
  else
    dir=$(find . -type d -not -path '*/.git/*' 2>/dev/null | fzf) && cd "$dir"
  fi
}

# please — re-run the last command with sudo. PREVIEWS the command and CONFIRMS
# first: this eval's your previous line as root, so a fat-fingered history entry
# (or a function that left something unexpected as the last command) should not
# silently run privileged. _core_confirm declines with no TTY, so this is fail-safe
# in a non-interactive context too.
please() {
  emulate -L zsh
  local last
  last="$(fc -ln -1 2>/dev/null)"
  if [[ -z "${last//[[:space:]]/}" ]]; then
    _core_err "please: no previous command to re-run"
    return 1
  fi
  _core_warn "about to run as root:  sudo ${last}"
  _core_confirm "proceed?" || {
    _core_warn "please: cancelled"
    return 1
  }
  eval "sudo ${last}"
}

# mkbak — timestamped backup of a file before you edit it
mkbak() { cp -- "$1" "$1.$(date +%Y%m%d-%H%M%S).bak"; }

# serve — quick HTTP server in the CWD, printing the URLs it's actually reachable
# at (tunnel IP first, then LAN). Replaces the old `serve` alias. Binds all
# interfaces on purpose: this is your ad-hoc file-transfer server. Optional port.
#   serve            # port 8000
#   serve 8080       # port 8080
serve() {
  local port="${1:-8000}" ip
  # Defensive: this binds ALL interfaces on purpose (ad-hoc file transfer), so say
  # so plainly — on an untrusted network the CWD is reachable by anyone who can
  # route to this host until you Ctrl-C.
  _core_warn "serve binds 0.0.0.0:${port} — the CWD is exposed on every interface"
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
