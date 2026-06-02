# core/zsh/tools.zsh
# ──────────────────────────────────────────────────────────────────────────────
# Tool detection + the single place every shell-hook tool is initialised. Load
# this FIRST (before options/history/aliases/fzf/bindings/plugins/op).
#
# Why this file exists: the modern CLI stack (eza, bat, fd, ...) is not present
# on every box, and package names differ per distro (fd -> `fdfind` on Debian,
# bat -> `batcat`). We detect what's installed, set HAVE_* flags + canonical
# binary names, and degrade gracefully instead of erroring on a bare box.
#
# This is also the ONE place zoxide/starship/atuin/mise are initialised. As of
# the 2026 refresh, starship + zoxide are CACHED: their `init zsh` output is
# stable, so we generate it once and `source` the cache (one cheap read) instead
# of spawning a subprocess on every shell start. atuin + mise stay live (their
# init legitimately varies with daemon/version). Measure with:
#     hyperfine 'zsh -i -c exit'
# ──────────────────────────────────────────────────────────────────────────────

# Interactive shells only. Scripts get raw POSIX.
[[ $- == *i* ]] || return 0

# user-local bin (mise/starship/atuin/clip/carapace land here) must be on PATH
# BEFORE we probe for those tools, or they won't be detected on a fresh shell.
[[ -d "$HOME/.local/bin" && ":$PATH:" != *":$HOME/.local/bin:"* ]] && export PATH="$HOME/.local/bin:$PATH"

_have() { command -v "$1" >/dev/null 2>&1; }

# ── Cache helper: source a tool's init script, regenerate only when the binary
# is newer than the cache (or the cache is missing). Turns an eval-of-subprocess
# into a plain source. Used for the tools whose init output is deterministic. ──
_cache_eval() { # _cache_eval <name> <command...>
  local name="$1"
  shift
  local dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
  local cache="$dir/${name}.zsh"
  local bin
  bin="$(command -v "$1" 2>/dev/null)"
  [[ -z "$bin" ]] && return 0
  if [[ ! -s "$cache" || "$bin" -nt "$cache" ]]; then
    [[ -d "$dir" ]] || mkdir -p "$dir"
    "$@" >"$cache" 2>/dev/null
  fi
  source "$cache"
}

# ── Resolve binaries that ship under alternate names on some distros ──────────
# Debian/Ubuntu ship fd as `fdfind` and bat as `batcat` to avoid name clashes.
if _have fd; then
  FD_BIN=fd
elif _have fdfind; then FD_BIN=fdfind; fi

if _have bat; then
  BAT_BIN=bat
elif _have batcat; then BAT_BIN=batcat; fi

# ── HAVE_* flags consumed by aliases.zsh / functions.zsh / fzf.zsh ────────────
_have eza && HAVE_EZA=1
_have rg && HAVE_RG=1
_have zoxide && HAVE_ZOXIDE=1
_have fzf && HAVE_FZF=1
_have starship && HAVE_STARSHIP=1
_have atuin && HAVE_ATUIN=1
_have delta && HAVE_DELTA=1
_have yazi && HAVE_YAZI=1
_have btop && HAVE_BTOP=1
_have dust && HAVE_DUST=1
_have procs && HAVE_PROCS=1
_have mise && HAVE_MISE=1
_have carapace && HAVE_CARAPACE=1 # completion engine — init in plugins.zsh
# 2026 additions (aliases.zsh guards each):
_have xh && HAVE_XH=1
_have glow && HAVE_GLOW=1
_have doggo && HAVE_DOGGO=1
_have gron && HAVE_GRON=1
_have sd && HAVE_SD=1
_have gum && HAVE_GUM=1
[[ -n ${FD_BIN:-} ]] && HAVE_FD=1
[[ -n ${BAT_BIN:-} ]] && HAVE_BAT=1

# ── Tool env — set BEFORE the init evals below ────────────────────────────────
# starship reads its theme from the default ~/.config/starship.toml (bootstrap
# symlinks core/starship/starship.toml there), so no STARSHIP_CONFIG is needed.
# starship already renders the active venv, so silence Python's own prefix.
export VIRTUAL_ENV_DISABLE_PROMPT=1
# atuin binds NOTHING automatically — bindings.zsh owns Ctrl+E (atuin TUI) and
# keeps Ctrl+R on the custom fzf history widget. (Replaces --disable-up-arrow.)
export ATUIN_NOBIND=true

# ── Initialise shell-hook tools ───────────────────────────────────────────────
# CACHED (deterministic init output):
[[ -n ${HAVE_STARSHIP:-} ]] && _cache_eval starship starship init zsh
[[ -n ${HAVE_ZOXIDE:-} ]] && _cache_eval zoxide zoxide init zsh
# LIVE (init varies with daemon/version — do not cache):
[[ -n ${HAVE_MISE:-} ]] && eval "$(mise activate zsh)"
[[ -n ${HAVE_ATUIN:-} ]] && eval "$(atuin init zsh)"
# NOTE on mise: this is the chpwd-hook activation. If you prefer native shims
# (mise/config.toml has experimental=true), switch to `mise activate zsh --shims`
# or put "$(mise where)"/shims on PATH and drop this line — pick ONE deliberately.

unfunction _have 2>/dev/null
