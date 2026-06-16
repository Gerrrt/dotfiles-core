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

# Accent colours for the nudge + welcome below (they feed `print -P %F{…}`). These
# come from ui.zsh's canonical palette ($_CORE_ACCENT_SPEC/$_CORE_MUTED_SPEC — the one
# place $COLORTERM is interpreted) when it's loaded, which it is in canonical order
# (ui precedes update). The COLORTERM branch below is a STANDALONE fallback for the
# unit tests, which source this module alone: it reproduces the same truecolor-hex vs
# 256-colour choice so a 16/256-colour TTY never gets a raw 24-bit escape.
if [[ -n ${_CORE_ACCENT_SPEC:-} ]]; then
  typeset -g _PKGUP_ACCENT=$_CORE_ACCENT_SPEC _PKGUP_MUTED=$_CORE_MUTED_SPEC
elif [[ "${COLORTERM:-}" == (24bit|truecolor) ]]; then
  typeset -g _PKGUP_ACCENT='#7aa2f7' _PKGUP_MUTED='#565f89'
else
  typeset -g _PKGUP_ACCENT=75 _PKGUP_MUTED=244
fi

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

# Best-effort LIST of upgradable package names — the names behind _pkgup_count's
# number, used by `up` to PREVIEW what will change before you confirm. Same non-root,
# no-system-mutation commands as _pkgup_count, emitting names instead of counting
# (brew skips the network `brew update` the count does — the nudge already ran it).
# Empty/unknown manager → nothing, so the caller just falls back to a name-only confirm.
_pkgup_list() {
  case "$(_pkgup_mgr)" in
  brew) brew outdated --quiet 2>/dev/null ;;
  pacman)
    if command -v checkupdates >/dev/null 2>&1; then
      checkupdates 2>/dev/null | awk '{print $1}'
    else pacman -Qu 2>/dev/null | awk '{print $1}'; fi
    ;;
  dnf) dnf -q --refresh check-update 2>/dev/null | awk '/^[a-zA-Z0-9]/{print $1}' ;;
  zypper) zypper -q list-updates 2>/dev/null | awk -F'|' '/^v /{gsub(/[[:space:]]/,"",$3); print $3}' ;;
  apt) apt-get -s upgrade 2>/dev/null | awk '/^Inst /{print $2}' ;;
  apk) apk list -u 2>/dev/null | awk '{print $1}' ;;
  emerge) command -v eix >/dev/null 2>&1 && eix -u --only-names 2>/dev/null ;;
  esac
}

# Background refresh → writes "<count>\n<epoch>" to the cache.
_pkgup_refresh() {
  local n
  n="$(_pkgup_count 2>/dev/null)"
  n="${n//[^0-9-]/}"
  : "${n:=-1}"
  mkdir -p "${_PKGUP_CACHE:h}"
  print -r -- "$n" >|"$_PKGUP_CACHE"       # >| : force past NO_CLOBBER (cache pre-exists)
  print -r -- "$(date +%s)" >>"$_PKGUP_CACHE"
}

# Manual force: `update-check`
update-check() {
  _core_wants_help "$1" && { _core_help "update-check" "refresh the cached 'updates available' nudge now"; return 0; }
  _pkgup_refresh && _pkgup_notice
}

# Print the one-line nudge from cache (instant; no work).
_pkgup_notice() {
  [[ -r "$_PKGUP_CACHE" ]] || return 0
  local count
  count="$(sed -n 1p "$_PKGUP_CACHE" 2>/dev/null)"
  [[ "$count" == <1-> ]] || return 0 # zsh numeric-range glob: only positive ints
  print -P "%F{$_PKGUP_ACCENT}󰚰 ${count} update$([[ $count -ne 1 ]] && print s) available%f %F{$_PKGUP_MUTED}— run \`up\` to apply%f"
}

# ── Startup hook: throttle + background the check, then show cached nudge ──────
# The manager probe (_pkgup_mgr — up to 7 `command -v` forks) used to run on EVERY
# interactive shell, in a synchronous `$()` on the critical path before the first
# prompt — against this stack's own startup-perf thesis (cached inits in tools.zsh,
# deferred plugins, the bench budget gate). It's only NEEDED when the once/day throttle
# window has actually elapsed and we're about to refresh, so it now lives INSIDE that
# branch. The nudge (_pkgup_notice) just reads the cache — no probe — so it still prints
# every shell. (A box with no manager simply has no positive count cached, so the nudge
# stays silent there exactly as before.)
if ((UPDATE_CHECK_ENABLED)); then
  () {
    local now last=0
    now="$(date +%s)"
    [[ -r "$_PKGUP_CACHE" ]] && last="$(sed -n 2p "$_PKGUP_CACHE" 2>/dev/null)"
    [[ "$last" == <-> ]] || last=0
    # Throttle FIRST (cheap: a date + a cache read), then — only when due — pay for the
    # manager probe. No elapsed window → no probe, the common per-shell path.
    if ((now - last >= UPDATE_CHECK_INTERVAL)) && [[ "$(_pkgup_mgr)" != none ]]; then
      # Claim the slot immediately (bump the timestamp) so sibling shells opened
      # in the same instant don't all fire, then refresh in a disowned subshell.
      mkdir -p "${_PKGUP_CACHE:h}"
      {
        print -r -- "$(sed -n 1p "$_PKGUP_CACHE" 2>/dev/null)"
        print -r -- "$now"
      } >|"$_PKGUP_CACHE" 2>/dev/null    # >| : force past NO_CLOBBER (cache pre-exists)
      { _pkgup_refresh; } &|
    fi
  }
  _pkgup_notice
fi

# ── First-run hint: once per machine, point a new shell at the cheat sheet ──────
# A brand-new clone gives no clue that `serve`, `extract`, `fif`, or the Ctrl-F/G
# widgets exist. Print ONE unobtrusive line the first time, throttled by a sentinel
# (like the nudge above), then never again. Set CORE_WELCOME=0 to silence entirely.
#
# Factored into a named function (not an inline anonymous block) so it's unit-testable
# — the greet-once / sentinel-persists / NO_COLOR contract is exercised by test-core.sh.
# The TTY gate lives at the CALL SITE, so the function itself is pure greet+sentinel
# logic the test can drive with captured stdout.
_core_welcome() {
  emulate -L zsh
  local stamp="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-core/.welcomed"
  [[ -e "$stamp" ]] && return 0
  # Only greet once the sentinel actually PERSISTS — otherwise a read-only state dir
  # (write fails) would re-greet on every shell start, forever. `>|` forces past
  # NO_CLOBBER; `|| return` bails (no greet) when we can't remember we did.
  mkdir -p "${stamp:h}" 2>/dev/null && : >|"$stamp" 2>/dev/null || return 0
  if [[ -z ${NO_COLOR:-} ]]; then
    print -P "%F{$_PKGUP_ACCENT}👋 dotfiles Core loaded%f %F{$_PKGUP_MUTED}— run \`core\` for functions, keys & maintenance%f"
  else
    print -r -- "👋 dotfiles Core loaded — run \`core\` for functions, keys & maintenance"
  fi
}
# Greet only an interactive TERMINAL — a redirected/captured stdout (or the load-order
# smoke test) gets nothing — and only when not disabled.
: "${CORE_WELCOME:=1}"
if ((CORE_WELCOME)) && [[ -t 1 ]]; then _core_welcome; fi

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
  # Help BEFORE anything else: without this, `up --help` fell through (not `-y`, so
  # yes=0) and proceeded to actually apply updates — a help flag must never do that.
  _core_wants_help "$1" && { _core_help "up [-y|--yes] [-n|--dry-run]" "apply package updates (interactive; -y auto-confirms where safe; -n only lists)"; return 0; }
  # Parse EVERY argument (not just $1) so flag ORDER doesn't matter and an unknown
  # flag or stray operand is REJECTED in Core's voice — matching the fail-closed
  # parsers in scripts/*.sh. The old `[[ "$1" == … ]]` form silently ignored a
  # second flag (`up -n -y`) and let a typo like `up --bogus` fall through to a real,
  # privileged update. Usage errors return 1, the convention every Core VERB uses
  # (serve/mkcd/cdup/…); the gate SCRIPTS use 2, but `up` is a verb, not a gate.
  local yes=0 dry=0 arg
  for arg in "$@"; do
    case "$arg" in
    -y | --yes) yes=1 ;;
    -n | --dry-run) dry=1 ;;
    *)
      _core_err "up: unexpected argument: $arg"
      local _sug
      _sug="$(_core_suggest "$arg" -y --yes -n --dry-run)"
      [[ -n "$_sug" ]] && _core_hint "did you mean ${_sug}?"
      _core_usage "up [-y|--yes] [-n|--dry-run]"
      return 1
      ;;
    esac
  done
  # -y (apply) and -n (inspect-only) are mutually exclusive — refuse the contradiction
  # rather than silently letting one win.
  if ((yes && dry)); then
    _core_err "up: -y/--yes and -n/--dry-run are mutually exclusive"
    _core_usage "up [-y|--yes] [-n|--dry-run]"
    return 1
  fi
  local y=()
  ((yes)) && y=(-y)
  local mgr
  mgr="$(_pkgup_mgr)"
  if [[ "$mgr" == none ]]; then
    _core_errbox "up: no supported package manager found" \
      "why: none of brew/pacman/dnf/zypper/apt/apk/emerge is on PATH" \
      "fix: install your distro's package manager, or update by hand"
    return 1
  fi
  # Dry run: show what WOULD upgrade and exit 0, touching nothing — the non-destructive
  # inspect that the count-only nudge and the (interactive-only) pre-confirm preview
  # didn't offer. Uses the same non-root, no-mutation _pkgup_list as the preview below.
  if ((dry)); then
    local -a pending
    pending=(${(f)"$(_pkgup_list 2>/dev/null)"})
    if ((${#pending})); then
      _core_ok "up: ${#pending} package$([[ ${#pending} -ne 1 ]] && echo s) upgradable via ${mgr}:"
      print -rl -- "${(@)pending/#/    }"
    else
      _core_ok "up: nothing to upgrade (via ${mgr})"
    fi
    return 0
  fi
  # Defensive pre-confirm (skipped by -y): name the manager BEFORE touching the
  # system, so `up` on the wrong box is a one-keystroke abort, not a surprise sync.
  # _core_confirm declines with no TTY, so `up` (sans -y) stays interactive-only.
  if ((! yes)); then
    # Preview WHAT will change, not just the manager: the nudge already shows a count,
    # so surface the names too — informed consent before a privileged, hard-to-undo
    # sync. Best-effort + capped (a 300-package upgrade shouldn't scroll the confirm
    # off-screen) and TTY-only (no point listing when the confirm below will decline).
    if [[ -t 2 ]]; then
      local -a pending
      pending=(${(f)"$(_pkgup_list 2>/dev/null)"})
      if ((${#pending})); then
        local n=${#pending} cap=20
        _core_warn "up: ${n} package$([[ $n -ne 1 ]] && echo s) upgradable via ${mgr}:"
        print -u2 -rl -- "${(@)pending[1,cap]/#/    }"
        # When the preview is capped, close the loop: point at the non-destructive
        # full listing instead of leaving "… and N more" as a dead end.
        ((n > cap)) && {
          print -u2 -- "    … and $((n - cap)) more"
          _core_hint "run \`up -n\` to list all ${n}"
        }
      fi
    fi
    _core_confirm "Apply updates with ${mgr}?" || {
      _core_warn "up: cancelled"
      return 1
    }
  fi
  case "$mgr" in
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
    # Unreachable (the `none` case is handled above) — kept as defence in depth.
    _core_err "up: no supported package manager found"
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
