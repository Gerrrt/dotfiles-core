# core/zsh/tools.zsh
# ──────────────────────────────────────────────────────────────────────────────
# Tool detection. Load this BEFORE aliases.zsh.
#
# Why this file exists: the modern CLI stack (eza, bat, fd, ...) is not present
# on every box, and package names differ per distro (fd -> `fdfind` on Debian,
# bat -> `batcat`). Rather than hardcode aliases that break on a fresh server,
# we detect what's actually installed and set HAVE_* flags + canonical binary
# names. aliases.zsh consumes these so a missing tool degrades gracefully to
# the classic command instead of erroring.
#
# Cross-distro note (2026): Debian-family distros are migrating to uutils (Rust
# coreutils, default target Ubuntu 26.04). Interactive `ls`/`cp` behavior may
# shift. The durable rule, enforced below: modern tools for interactive use,
# POSIX commands in scripts. Never alias inside scripts — these only fire in
# interactive shells.
# ──────────────────────────────────────────────────────────────────────────────

# Only set up interactive niceties in interactive shells. Scripts get raw POSIX.
[[ $- == *i* ]] || return 0

_have() { command -v "$1" >/dev/null 2>&1; }

# ── Resolve binaries that ship under alternate names on some distros ──────────
# Debian/Ubuntu ship fd as `fdfind` and bat as `batcat` to avoid name clashes.
if _have fd;       then FD_BIN=fd
elif _have fdfind; then FD_BIN=fdfind; fi

if _have bat;       then BAT_BIN=bat
elif _have batcat;  then BAT_BIN=batcat; fi

# ── HAVE_* flags consumed by aliases.zsh / functions.zsh ──────────────────────
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
[[ -n ${FD_BIN:-}  ]] && HAVE_FD=1
[[ -n ${BAT_BIN:-} ]] && HAVE_BAT=1

# ── Initialize tools that hook the shell (guarded so a missing tool is silent)─
[[ -n ${HAVE_ZOXIDE:-}   ]] && eval "$(zoxide init zsh)"
[[ -n ${HAVE_STARSHIP:-} ]] && eval "$(starship init zsh)"
[[ -n ${HAVE_ATUIN:-}    ]] && eval "$(atuin init zsh --disable-up-arrow)"

unfunction _have 2>/dev/null
