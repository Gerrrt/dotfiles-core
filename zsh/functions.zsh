# core/zsh/functions.zsh
# ──────────────────────────────────────────────────────────────────────────────
# Cross-OS shell functions. Pure POSIX-ish where possible so they behave the
# same on macOS zsh, Linux zsh, and Alpine's busybox-adjacent environment.
# Nothing OS-specific or offensive here — those live in the OS / Kali repos.
# ──────────────────────────────────────────────────────────────────────────────

# mkcd — make a directory and cd into it
mkcd() {
  _core_wants_help "$1" && { _core_help "mkcd <dir>" "make a directory (and parents) and cd into it"; return 0; }
  [[ -z "$1" ]] && { _core_usage "mkcd <dir>"; return 1; }
  mkdir -p -- "$1" && cd -- "$1"
}

# cdup — climb N directories (cdup 3 == cd ../../..). NOT named `up`: that's the
# package-updater in update.zsh. N defaults to 1 and must be a positive integer —
# a typo'd `cdup x` should say so, not silently no-op (the loop never runs) and leave
# you wondering why you didn't move.
cdup() {
  emulate -L zsh
  _core_wants_help "$1" && { _core_help "cdup [n]" "climb n directories (default 1); cdup 3 == cd ../../.."; return 0; }
  local n="${1:-1}" p=""
  if [[ "$n" != <-> ]] || ((n < 1)); then
    _core_err "cdup: count must be a positive integer (got '$n')"
    _core_usage "cdup [n]"
    return 1
  fi
  while ((n-- > 0)); do p="../$p"; done
  cd "$p" || return
}

# _extract_dispatch — the raw unpack, NO safety guard. Split out of extract() so the
# "contain a tarbomb in a subdir" path (below) can re-run the unpack in that subdir
# WITHOUT re-entering the guard (which would see the same multi-entry archive and
# recurse forever). ouch (if installed) handles every format from one binary; the
# hand-rolled case is the bare-box fallback.
_extract_dispatch() {
  [[ -n ${HAVE_OUCH:-} ]] && { ouch decompress "$1"; return; }
  case "$1" in
  *.tar.bz2 | *.tbz2) tar xjf "$1" ;;
  *.tar.gz | *.tgz) tar xzf "$1" ;;
  *.tar.xz) tar xJf "$1" ;;
  *.tar) tar xf "$1" ;;
  *.bz2) bunzip2 -f "$1" ;;
  *.gz) gunzip -f "$1" ;;
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

# extract — one command for any archive, with two defences applied BEFORE anything
# is written to disk:
#   • tarbomb guard — an archive with several top-level entries would scatter them
#     across the CWD; offer to contain it in ./<archive-name>/ instead.
#   • clobber guard — if a top-level entry already exists, confirm before overwriting.
# Both peek at the listing first (best-effort per format; unlistable → just unpack).
# Confirmation is via _core_confirm, which DECLINES with no TTY — so a scripted /
# piped run never silently overwrites, and a single-rooted archive (the common case)
# sails straight through untouched.
extract() {
  emulate -L zsh
  _core_wants_help "$1" && { _core_help "extract <archive>" "unpack any archive (tar/zip/7z/rar/…); guards tarbombs + clobbers"; return 0; }
  [[ -z "$1" ]] && { _core_usage "extract <archive>"; return 1; }
  [[ -f "$1" ]] || {
    _core_err "extract: '$1' is not a file"
    return 1
  }
  local archive="$1" abs="${1:A}"

  # Entries this archive would write. tar/zip extract relative to the CWD, so their
  # top-level names are CWD-relative; gz/bz2 instead write NEXT TO the archive, so the
  # target is the archive's full path minus the compression suffix (${abs:r}) — not a
  # CWD basename. Getting that right means `extract /some/dir/file.gz` correctly checks
  # /some/dir/file for clobber, not ./file. Drop any '.'/'' rows (leading-'./'  tars).
  # We list/dispatch via $abs throughout, which also sidesteps a leading-'-' filename
  # being read as an option by tar/unzip/gunzip. Unlistable formats → empty → no guard.
  local -a top
  case "$archive" in
  *.tar.bz2 | *.tbz2 | *.tar.gz | *.tgz | *.tar.xz | *.tar)
    top=(${(f)"$(tar tf "$abs" 2>/dev/null | cut -d/ -f1 | sort -u)"}) ;;
  *.zip)
    top=(${(f)"$(unzip -Z1 "$abs" 2>/dev/null | cut -d/ -f1 | sort -u)"}) ;;
  *.gz | *.bz2)
    top=("${abs:r}") ;;
  esac
  top=(${top:#.}) # strip a bare '.' top entry (leading './' archives)

  if ((${#top})); then
    # Tarbomb: more than one top-level entry. Contain it in a subdir (default-safe:
    # with no TTY _core_confirm declines and we fall through to extract-in-place,
    # having at least warned).
    if ((${#top} > 1)); then
      local into="${archive:t:r}"
      into="${into%.tar}"
      _core_warn "extract: '${archive:t}' has ${#top} top-level entries — would scatter across $(pwd)"
      if _core_confirm "extract into ./${into}/ instead?"; then
        mkdir -p -- "$into" || {
          _core_err "extract: cannot create '$into'"
          return 1
        }
        (cd -- "$into" && _extract_dispatch "$abs")
        return
      fi
    fi
    # Clobber: any existing top-level target. Confirm before overwriting; declined
    # (or no TTY) → abort with nothing touched.
    local t
    local -a clobber=()
    for t in "${top[@]}"; do [[ -e "$t" ]] && clobber+=("$t"); done
    if ((${#clobber})); then
      _core_warn "extract: would overwrite existing: ${clobber[*]}"
      _core_confirm "overwrite?" || {
        _core_warn "extract: cancelled (nothing overwritten)"
        return 1
      }
    fi
  fi

  _extract_dispatch "$abs"
}

# fcd — fuzzy-cd into any subdirectory (needs fzf + fd, degrades to find)
fcd() {
  _core_wants_help "$1" && { _core_help "fcd" "fuzzy-cd into any subdirectory (fzf + fd, degrades to find)"; return 0; }
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
  _core_wants_help "$1" && { _core_help "please" "re-run the last command with sudo (previews + confirms first)"; return 0; }
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

# mkbak — timestamped backup of a file before you edit it. Validates its input in
# Core's voice instead of letting `cp` emit a raw "missing operand"/"No such file"
# (the rest of functions.zsh — mkcd, extract — guards the same way).
mkbak() {
  emulate -L zsh
  _core_wants_help "$1" && { _core_help "mkbak <file>" "timestamped .bak copy of a file before you edit it"; return 0; }
  [[ -z "$1" ]] && {
    _core_usage "mkbak <file>"
    return 1
  }
  [[ -f "$1" ]] || {
    _core_err "mkbak: '$1' is not a regular file"
    return 1
  }
  cp -- "$1" "$1.$(date +%Y%m%d-%H%M%S).bak"
}

# serve — quick HTTP server in the CWD, printing the URLs it's actually reachable
# at (tunnel IP first, then LAN). Replaces the old `serve` alias. Binds all
# interfaces on purpose: this is your ad-hoc file-transfer server. Optional port.
#   serve            # port 8000
#   serve 8080       # port 8080
serve() {
  emulate -L zsh
  _core_wants_help "$1" && { _core_help "serve [port]" "HTTP server in the CWD (default 8000); binds all interfaces"; return 0; }
  local port="${1:-8000}" ip
  # Defensive input handling: a typo'd port should be rejected cleanly, not handed to
  # python to fail with a stack trace (or, worse, a non-numeric value coerced oddly).
  if [[ "$port" != <-> ]] || ((port < 1 || port > 65535)); then
    _core_err "serve: port must be 1-65535 (got '$port')"
    _core_usage "serve [port]"
    return 1
  fi
  _core_have python3 || {
    _core_err "serve: requires python3"
    _core_hint "install python3, then retry"
    return 1
  }
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

# core-help (alias: cheat) — a scannable cheat sheet of what Core actually gives
# you on this box: the shell functions, the custom keybindings, and the update /
# maintenance verbs. Static + instant — the discoverability surface for the Core
# layer (the shell counterpart to which-key in Neovim). Rows are "key|description"
# pairs grouped under "§heading" markers, so the list stays trivially editable.
core-help() {
  emulate -L zsh
  # Raw ANSI (not prompt %F) + `print -r` below, so a literal backslash in a key
  # (Ctrl-\) survives — print -P would consume it as an escape. Colour only on a
  # TTY; piped/redirected output stays plain.
  local title=$'\e[1;38;2;122;162;247m' te=$'\e[0m'
  local kc=$'\e[36m' ke=$'\e[0m' dc=$'\e[38;2;86;95;137m' de=$'\e[0m'
  if [[ ! -t 1 || -n ${NO_COLOR:-} ]]; then title='' te='' kc='' ke='' dc='' de=''; fi
  # Rows are "key|description" or "key|description|requires" — the optional third
  # field names a command this entry NEEDS. When it's absent on THIS box the row is
  # dimmed and tagged "— needs <cmd>", so the cheat sheet reflects what actually works
  # here instead of advertising widgets/verbs that would no-op (fzf/atuin/sesh/zoxide
  # aren't on every box). Verbs that degrade gracefully (extract, up, maint) carry no
  # requirement — they always work.
  local -a rows=(
    "§navigation & files"
    "mkcd <dir>|make a directory and cd into it"
    "cdup [n]|climb n directories (default 1)"
    "extract <archive>|unpack any archive (tar/zip/7z/rar/…)"
    "mkbak <file>|timestamped .bak copy before you edit"
    "fcd|fuzzy-cd into any subdirectory|fzf"
    "serve [port]|HTTP server in the CWD, prints reachable URLs|python3"
    "§search"
    "fif <text>|find text inside files (rg + fzf + preview)|fzf"
    "fbr|fuzzy git-branch checkout|fzf"
    "§keybindings"
    "Ctrl-F|file picker → insert path at cursor|fzf"
    "Ctrl-R|history search|fzf"
    "Ctrl-E|Atuin history TUI|atuin"
    "Ctrl-G|session picker (sesh)|sesh"
    "Alt-Z|zoxide project jump|zoxide"
    "Ctrl-\\|toggle autosuggestions"
    "§updates & maintenance"
    "up [-y]|apply package updates (interactive; confirms first)"
    "update-check|refresh the 'updates available' nudge"
    "maint-install [HH:MM]|schedule the daily safe-update job"
    "maint-run|run daily maintenance now"
    "maint-log [-f]|view (or follow) the maintenance log"
  )
  print -r -- "${title}dotfiles Core — cheat sheet${te} ${dc}(run \`core-help\` anytime)${de}"
  # Key column is derived from the WIDEST key, not a fixed 22 — so alignment stays
  # correct if a longer verb is ever added (the old hard-coded width silently broke
  # alignment past 22 chars) and isn't padded wider than the content needs. On a narrow
  # terminal, clamp it (and truncate an over-long key) so it can't swallow the whole
  # line and leave no room for the description.
  local line key desc req kw=0
  local -a parts
  for line in "${rows[@]}"; do
    [[ "$line" == §* ]] && continue
    key="${line%%|*}"
    ((${#key} > kw)) && kw=${#key}
  done
  local cols=${COLUMNS:-80}
  ((kw > cols - 22)) && kw=$((cols - 22)) # keep room for a readable description
  ((kw < 6)) && kw=6
  for line in "${rows[@]}"; do
    if [[ "$line" == §* ]]; then
      print -r -- "${title}${line#§}${te}"
    else
      parts=("${(@s:|:)line}")
      key="${parts[1]}"
      desc="${parts[2]}"
      req="${parts[3]:-}" # optional: a command this row needs to actually work
      key="${key[1,kw]}"  # truncate an over-long key to the (possibly clamped) column
      if [[ -n "$req" ]] && ! _core_have "$req"; then
        # Unavailable on this box — dim the whole row and name what to install.
        print -r -- "  ${dc}${(r:$kw:)key} ${desc} — needs ${req}${de}"
      else
        print -r -- "  ${kc}${(r:$kw:)key}${ke} ${dc}${desc}${de}"
      fi
    fi
  done
  print -r -- "${dc}  1Password: opsecret · openv · optoken · opssh    full reference: README.md${de}"
}
alias cheat='core-help'
