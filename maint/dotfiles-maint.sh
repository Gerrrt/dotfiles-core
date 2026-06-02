#!/usr/bin/env bash
# core/maint/dotfiles-maint.sh — the daily "update everything (that's safe)" runner.
# ──────────────────────────────────────────────────────────────────────────────
# Invoked by a scheduler (systemd user timer / launchd / cron) at a fixed time —
# install it with `maint-install` (see core/zsh/maint.zsh). Designed to run
# UNATTENDED and NON-INTERACTIVE: every step is guarded, time-limited, and failure
# of one step never aborts the rest. Updates the USER-SPACE stack (brew, plugin
# managers, editor) automatically — those are low-risk. SYSTEM packages are only
# *checked* (the shell nudge cache is refreshed); applying them stays manual via
# `up`, unless you explicitly opt in (and never on Arch/Gentoo/Kali — see below).
#
# Env knobs (set in the scheduler unit or your shell before a manual run):
#   MAINT_SYSTEM_UPGRADE=0   # 1 = also apply system pkgs (apt/dnf/zypper/brew ONLY)
#   ZPLUGINDIR=~/.config/zsh/plugins
#   MAINT_NVIM_TIMEOUT=600    MAINT_BREW_TIMEOUT=900
#   MAINT_ENABLED=1          # 0 = no-op (e.g. drop a guard on a Kali engagement box)
# ──────────────────────────────────────────────────────────────────────────────

# A scheduler hands us a minimal environment — build a sane PATH and find brew/mise/nvim.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
export HOME="${HOME:?}"
: "${XDG_CACHE_HOME:=$HOME/.cache}"
: "${XDG_STATE_HOME:=$HOME/.local/state}"
: "${ZPLUGINDIR:=${ZDOTDIR:-$HOME/.config/zsh}/plugins}"
: "${MAINT_ENABLED:=1}"
: "${MAINT_SYSTEM_UPGRADE:=0}"
: "${MAINT_NVIM_TIMEOUT:=600}"
: "${MAINT_BREW_TIMEOUT:=900}"

[[ "$MAINT_ENABLED" == 1 ]] || exit 0

LOG_DIR="$XDG_STATE_HOME/dotfiles-maint"
LOG="$LOG_DIR/maint.log"
LOCK="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-maint.lock"
mkdir -p "$LOG_DIR"

# ── single-instance lock (mkdir is atomic) ───────────────────────────────────
if ! mkdir "$LOCK" 2>/dev/null; then
  echo "$(date '+%F %T')  another run holds the lock ($LOCK) — exiting" >>"$LOG"
  exit 0
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

# ── keep the log from growing forever (last ~800 lines) ───────────────────────
if [[ -f "$LOG" ]] && [[ "$(wc -l <"$LOG" 2>/dev/null || echo 0)" -gt 800 ]]; then
  tail -n 600 "$LOG" >"$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi

log() { echo "$(date '+%F %T')  $*" | tee -a "$LOG"; }
have() { command -v "$1" >/dev/null 2>&1; }

# portable timeout (GNU `timeout` / macOS `gtimeout`; else run unbounded)
_to() {
  local secs="$1"
  shift
  if have timeout; then
    timeout "$secs" "$@"
  elif have gtimeout; then
    gtimeout "$secs" "$@"
  else "$@"; fi
}

# run a labeled step, capture rc, never abort the script
step() {
  local label="$1"
  shift
  log "▶ ${label}"
  if "$@" >>"$LOG" 2>&1; then log "  ✓ ${label}"; else log "  ✗ ${label} (rc=$?) — continuing"; fi
}

log "═══════════ dotfiles-maint start ($(uname -s) $(hostname 2>/dev/null)) ═══════════"

# ── Homebrew ──────────────────────────────────────────────────────────────────
if have brew || [[ -x /opt/homebrew/bin/brew || -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  have brew || eval "$([[ -x /opt/homebrew/bin/brew ]] && /opt/homebrew/bin/brew shellenv || /home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  step "brew update" _to "$MAINT_BREW_TIMEOUT" brew update
  step "brew upgrade" _to "$MAINT_BREW_TIMEOUT" brew upgrade
  step "brew cleanup" brew cleanup -s
fi

# ── mise (runtime/tool versions per your config) ──────────────────────────────
if have mise; then
  step "mise plugins update" mise plugins update
  step "mise upgrade" mise upgrade --yes
fi

# ── zsh plugins (mirrors your zplugin-update: fast-forward pull each repo) ─────
if [[ -d "$ZPLUGINDIR" ]]; then
  log "▶ zsh plugins ($ZPLUGINDIR)"
  for d in "$ZPLUGINDIR"/*/; do
    [[ -d "$d/.git" ]] || continue
    name="$(basename "$d")"
    if git -C "$d" pull --ff-only >>"$LOG" 2>&1; then log "  ✓ ${name}"; else log "  ✗ ${name} (pull failed) — continuing"; fi
  done
fi

# ── tmux plugins (TPM) ────────────────────────────────────────────────────────
TPM="$HOME/.config/tmux/plugins/tpm/bin"
if [[ -x "$TPM/update_plugins" ]]; then
  step "tmux: install new plugins" "$TPM/install_plugins"
  step "tmux: update plugins" "$TPM/update_plugins" all
fi

# ── Neovim: lazy.nvim sync + treesitter parsers + Mason registry ──────────────
if have nvim; then
  # one headless session: Lazy! (bang = synchronous), then TSUpdate, then Mason, then quit.
  step "neovim: Lazy sync / TSUpdate / MasonUpdate" \
    _to "$MAINT_NVIM_TIMEOUT" nvim --headless \
    "+Lazy! sync" "+silent! TSUpdateSync" "+silent! MasonUpdate" "+qa!"
fi

# ── System packages: refresh the shell-nudge cache (NON-ROOT count) ───────────
# Distro detection for the Kali / opt-in apply guard below.
OS_ID=""
[[ -r /etc/os-release ]] && OS_ID="$(
  . /etc/os-release 2>/dev/null
  echo "$ID"
)"
PKG_CACHE="$XDG_CACHE_HOME/zsh/pkg-updates"
mkdir -p "${PKG_CACHE%/*}"
count=-1
if have brew; then
  count=$(brew outdated --quiet 2>/dev/null | grep -c .)
elif have checkupdates; then
  count=$(checkupdates 2>/dev/null | grep -c .)
elif have pacman; then
  count=$(pacman -Qu 2>/dev/null | grep -c .)
elif have dnf; then
  count=$(dnf -q --refresh check-update 2>/dev/null | grep -cE '^[a-zA-Z0-9][^ ]*[[:space:]]')
elif have zypper; then
  count=$(zypper -q list-updates 2>/dev/null | grep -c '^v ')
elif have apt-get; then
  count=$(apt-get -s upgrade 2>/dev/null | grep -cE '^Inst ')
elif have apk; then
  count=$(apk list -u 2>/dev/null | grep -c .)
fi
printf '%s\n%s\n' "${count:--1}" "$(date +%s)" >"$PKG_CACHE"
log "system packages: ${count} upgradable (cache refreshed; apply with \`up\`)"

# ── Optional system apply (opt-in, and only where unattended is sane) ─────────
if [[ "$MAINT_SYSTEM_UPGRADE" == 1 ]]; then
  if [[ "$OS_ID" == kali ]]; then
    log "system upgrade SKIPPED: Kali — update engagement boxes by hand between ops"
  elif have pacman || have emerge; then
    log "system upgrade SKIPPED: Arch/Gentoo must not be upgraded unattended — run \`up\`"
  else
    # passwordless sudo required for this to work non-interactively; otherwise it
    # logs a sudo failure and moves on (safe).
    if have brew; then
      : # brew already upgraded above
    elif have dnf; then
      step "system: dnf upgrade" sudo -n dnf -y upgrade --refresh
    elif have zypper; then
      step "system: zypper up" sudo -n zypper --non-interactive up
    elif have apt-get; then
      step "system: apt upgrade" sh -c 'sudo -n apt-get update && sudo -n apt-get -y full-upgrade && sudo -n apt-get -y autoremove'
    fi
  fi
fi

log "═══════════ dotfiles-maint done ═══════════"
