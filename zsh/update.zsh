# core/zsh/update.zsh
# ──────────────────────────────────────────────────────────────────────────────
# "Tell me when there are updates, don't make me remember." A throttled,
# fully-backgrounded check on shell start that prints a single one-line nudge if
# packages are upgradable — then APPLYING is your call via `up`.
#
# WHY NOT update+upgrade on every shell:
#   • blocks every pane/split/sesh-session on a package sync (kills the startup
#     work in tools.zsh); concurrent shells deadlock on the dpkg/rpm lock
#   • needs root on every shell (password prompt, or passwordless sudo = privesc)
#   • unattended `-y` upgrades are dangerous on Arch (partial-upgrade breakage),
#     Gentoo (multi-hour compiles), and Kali (engagement reproducibility)
#   • hangs when offline
# So: this CHECKS (no root, backgrounded, throttled to once/day) and NUDGES. The
# real upgrade is `up` (interactive) or an OS-layer timer — see the tail comment.
#
# LOAD ORDER: source near the END of your loader (after `plugins`), so the notice
# prints just above your first prompt.
#
# Config (override in os/local before this is sourced):
#   UPDATE_CHECK_ENABLED   1        # set 0 to disable the check entirely (e.g. Kali during ops)
#   UPDATE_CHECK_INTERVAL  86400    # seconds between background checks
# ──────────────────────────────────────────────────────────────────────────────

[[ $- == *i* ]] || return 0
: "${UPDATE_CHECK_ENABLED:=1}"
: "${UPDATE_CHECK_INTERVAL:=86400}"
typeset -g _PKGUP_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/pkg-updates"

# privilege helper: sudo, else doas (Alpine), else run bare
_pkgup_priv() {
  if command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  elif command -v doas >/dev/null 2>&1; then
    doas "$@"
  else "$@"; fi
}

# which package manager is this box? (brew wins on macOS)
_pkgup_mgr() {
  if command -v brew >/dev/null 2>&1; then
    echo brew
  elif command -v pacman >/dev/null 2>&1; then
    echo pacman
  elif command -v dnf >/dev/null 2>&1; then
    echo dnf
  elif command -v zypper >/dev/null 2>&1; then
    echo zypper
  elif command -v apt-get >/dev/null 2>&1; then
    echo apt
  elif command -v apk >/dev/null 2>&1; then
    echo apk
  elif command -v emerge >/dev/null 2>&1; then
    echo emerge
  else echo none; fi
}

# Best-effort, NON-ROOT count of upgradable packages. Runs in the background.
# Offline / unknown → prints -1 (caller stays silent). Never touches the system.
_pkgup_count() {
  case "$(_pkgup_mgr)" in
  brew)
    brew update >/dev/null 2>&1
    brew outdated --quiet 2>/dev/null | grep -c .
    ;;
  pacman)
    # checkupdates (pacman-contrib) syncs a copy in user space — no root, no
    # touching the real DB (which would risk a partial upgrade). Fallback: -Qu.
    if command -v checkupdates >/dev/null 2>&1; then
      checkupdates 2>/dev/null | grep -c .
    else pacman -Qu 2>/dev/null | grep -c .; fi
    ;;
  dnf)
    # check-update: exit 100 = updates available, 0 = none; no root needed
    dnf -q --refresh check-update 2>/dev/null | grep -cE '^[a-zA-Z0-9][^ ]*[[:space:]]'
    ;;
  zypper)
    zypper -q list-updates 2>/dev/null | grep -c '^v '
    ;;
  apt)
    # -s = simulate against EXISTING lists (no root, no network). Count may be
    # stale until something runs `apt update`; `up` does the real refresh.
    apt-get -s upgrade 2>/dev/null | grep -cE '^Inst '
    ;;
  apk)
    apk list -u 2>/dev/null | grep -c .
    ;;
  emerge)
    # Gentoo: a real @world calc is far too heavy to background. Only report if
    # eix is present (cheap, reads its own cache); otherwise stay silent (-1).
    if command -v eix >/dev/null 2>&1; then
      eix -u --only-names 2>/dev/null | grep -c .
    else echo -1; fi
    ;;
  *) echo -1 ;;
  esac
}

# Background refresh → writes "<count>\n<epoch>" to the cache.
_pkgup_refresh() {
  local n
  n="$(_pkgup_count 2>/dev/null)"
  n="${n//[^0-9-]/}"
  : "${n:=-1}"
  mkdir -p "${_PKGUP_CACHE:h}"
  print -r -- "$n" >"$_PKGUP_CACHE"
  print -r -- "$(date +%s)" >>"$_PKGUP_CACHE"
}

# Manual force: `update-check`
update-check() { _pkgup_refresh && _pkgup_notice; }

# Print the one-line nudge from cache (instant; no work).
_pkgup_notice() {
  [[ -r "$_PKGUP_CACHE" ]] || return 0
  local count
  count="$(sed -n 1p "$_PKGUP_CACHE" 2>/dev/null)"
  [[ "$count" == <1-> ]] || return 0 # zsh numeric-range glob: only positive ints
  print -P "%F{#7aa2f7}󰚰 ${count} update$([[ $count -ne 1 ]] && print s) available%f %F{#565f89}— run \`up\` to apply%f"
}

# ── Startup hook: throttle + background the check, then show cached nudge ──────
if ((UPDATE_CHECK_ENABLED)) && [[ "$(_pkgup_mgr)" != none ]]; then
  () {
    local now last=0
    now="$(date +%s)"
    [[ -r "$_PKGUP_CACHE" ]] && last="$(sed -n 2p "$_PKGUP_CACHE" 2>/dev/null)"
    [[ "$last" == <-> ]] || last=0
    if ((now - last >= UPDATE_CHECK_INTERVAL)); then
      # Claim the slot immediately (bump the timestamp) so sibling shells opened
      # in the same instant don't all fire, then refresh in a disowned subshell.
      mkdir -p "${_PKGUP_CACHE:h}"
      {
        print -r -- "$(sed -n 1p "$_PKGUP_CACHE" 2>/dev/null)"
        print -r -- "$now"
      } >"$_PKGUP_CACHE" 2>/dev/null
      { _pkgup_refresh; } &|
    fi
  }
  _pkgup_notice
fi

# ══════════════════════════════════════════════════════════════════════════════
# up — apply updates. INTERACTIVE by design. `up -y` auto-confirms ONLY on the
# package managers where that's safe (apt/dnf/zypper). pacman/emerge are NEVER
# auto-confirmed (Arch partial-upgrade / Gentoo compile risk). Refreshes the
# cache afterward so the nudge clears.
#   up        # review & confirm
#   up -y     # auto-confirm where safe
# ══════════════════════════════════════════════════════════════════════════════
up() {
  emulate -L zsh
  local yes=0
  [[ "$1" == (-y|--yes) ]] && yes=1
  local y=()
  ((yes)) && y=(-y)
  case "$(_pkgup_mgr)" in
  brew) brew update && brew upgrade && brew cleanup ;;
  pacman) _pkgup_priv pacman -Syu ;; # full sync only; never partial
  dnf) _pkgup_priv dnf upgrade --refresh "${y[@]}" ;;
  zypper) if grep -qi tumbleweed /etc/os-release 2>/dev/null; then
    _pkgup_priv zypper dup "${y[@]}"
  else _pkgup_priv zypper up "${y[@]}"; fi ;;
  apt) _pkgup_priv apt-get update &&
    _pkgup_priv apt-get full-upgrade "${y[@]}" &&
    _pkgup_priv apt-get autoremove "${y[@]}" ;;
  apk) _pkgup_priv apk update && _pkgup_priv apk upgrade ;;
  emerge) _pkgup_priv emerge --sync && _pkgup_priv emerge -auvDN @world ;; # -a always asks
  *)
    echo "up: no supported package manager found" >&2
    return 1
    ;;
  esac
  _pkgup_refresh 2>/dev/null
}

# ── True hands-off auto-APPLY belongs at the OS layer, not here ───────────────
# If you want a box to update itself unattended, do it with the OS scheduler in
# that distro's repo — NOT in this portable file, and NOT on shell start:
#   • Fedora : dnf-automatic  (set apply_updates=yes; security-only is the sane default)
#   • Debian : unattended-upgrades  (security pocket only)
#   • any    : a systemd timer running `up -y`  (weekly, with Persistent=true)
#   • Arch / Gentoo : DON'T. Update them by hand with `up`.
#   • Kali   : DON'T auto-apply on an engagement box — pin versions, update between ops.
