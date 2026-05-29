# core/zsh/tools.zsh
# ──────────────────────────────────────────────────────────────────────────────
# Tool detection + the single place every shell-hook tool is initialised. Load
# this FIRST (before aliases/fzf/bindings/plugins/op).
#
# Why this file exists: the modern CLI stack (eza, bat, fd, ...) is not present
# on every box, and package names differ per distro (fd -> `fdfind` on Debian,
# bat -> `batcat`). We detect what's installed, set HAVE_* flags + canonical
# binary names, and degrade gracefully instead of erroring on a bare box.
#
# This is also the ONE place zoxide/starship/atuin/mise are initialised, so the
# per-tool files the Mac used to keep (atuin.zsh, prompt.zsh) are gone — their
# real settings were folded in below to avoid double-initialising.
#
# Cross-distro note (2026): Debian-family is migrating to uutils (Rust
# coreutils, default target Ubuntu 26.04). The durable rule: modern tools for
# interactive use, POSIX in scripts. These only fire in interactive shells.
# ──────────────────────────────────────────────────────────────────────────────

# Interactive shells only. Scripts get raw POSIX.
[[ $- == *i* ]] || return 0

# user-local bin (mise/starship/atuin/clip land here) must be on PATH BEFORE we
# probe for those tools, or they won't be detected on a fresh shell.
[[ -d "$HOME/.local/bin" && ":$PATH:" != *":$HOME/.local/bin:"* ]] && export PATH="$HOME/.local/bin:$PATH"

_have() { command -v "$1" >/dev/null 2>&1; }

# ── Resolve binaries that ship under alternate names on some distros ──────────
# Debian/Ubuntu ship fd as `fdfind` and bat as `batcat` to avoid name clashes.
if _have fd;       then FD_BIN=fd
elif _have fdfind; then FD_BIN=fdfind; fi

if _have bat;       then BAT_BIN=bat
elif _have batcat;  then BAT_BIN=batcat; fi

# ── HAVE_* flags consumed by aliases.zsh / functions.zsh / fzf.zsh ────────────
_have eza      && HAVE_EZA=1
_have rg       && HAVE_RG=1
_have zoxide   && HAVE_ZOXIDE=1
_have fzf      && HAVE_FZF=1
_have starship && HAVE_STARSHIP=1
_have atuin    && HAVE_ATUIN=1
_have delta    && HAVE_DELTA=1
_have yazi     && HAVE_YAZI=1
_have btop     && HAVE_BTOP=1
_have dust     && HAVE_DUST=1
_have procs    && HAVE_PROCS=1
_have mise     && HAVE_MISE=1
[[ -n ${FD_BIN:-}  ]] && HAVE_FD=1
[[ -n ${BAT_BIN:-} ]] && HAVE_BAT=1

# ── Tool env — set BEFORE the init evals below ────────────────────────────────
# starship reads its theme from the default ~/.config/starship.toml (bootstrap
# symlinks core/starship/starship.toml there), so no STARSHIP_CONFIG is needed.
# starship already renders the active venv, so silence Python's own prefix.
export VIRTUAL_ENV_DISABLE_PROMPT=1
# atuin binds NOTHING automatically — bindings.zsh owns Ctrl+E (atuin TUI) and
# keeps Ctrl+R on the custom fzf history widget. (Replaces --disable-up-arrow.)
export ATUIN_NOBIND=true

# ── Initialise tools that hook the shell (guarded so a missing tool is silent)─
[[ -n ${HAVE_MISE:-}     ]] && eval "$(mise activate zsh)"
[[ -n ${HAVE_ZOXIDE:-}   ]] && eval "$(zoxide init zsh)"
[[ -n ${HAVE_STARSHIP:-} ]] && eval "$(starship init zsh)"
[[ -n ${HAVE_ATUIN:-}    ]] && eval "$(atuin init zsh)"

unfunction _have 2>/dev/null
