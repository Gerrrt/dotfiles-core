# shellcheck shell=bash
# core/lib/ux.sh — shared BASH terminal-UX primitives (B5).
# ──────────────────────────────────────────────────────────────────────────────
# ONE definition of the colour palette, the UTF-8→ASCII glyph fallback, and the
# spinner for the bash layer — so the dev-tooling gates (scripts/lib/common.sh) and
# each OS repo's pre-shell installer (bootstrap.sh) stop hand-rolling their own copies
# that drift. zsh/ui.zsh is the zsh-runtime counterpart of this file; this is its bash
# sibling, and unlike common.sh it IS vendored into every OS repo (it's in core.manifest)
# precisely so bootstrap.sh — which runs before any zsh config and so cannot source
# ui.zsh — can `source core/lib/ux.sh` instead of duplicating ~80 lines.
#
# SOURCED, not run: no shebang, mode 100644 (the audit's exec-bit section asserts this for
# lib/*.sh, the bash sibling of the sourced zsh/*.zsh modules). bash 3.2-safe (macOS): no
# associative arrays, no mapfile, no ${x,,}.
#
# Usage:
#   source "<path>/core/lib/ux.sh"
#   ux_palette; ux_glyphs            # already called at source time; re-call after a flag
#   ux_spin "installing" some-cmd …  # spinner that returns the command's exit status
# ──────────────────────────────────────────────────────────────────────────────

# UX_* are a PALETTE/GLYPH API consumed by sourcers (common.sh, bootstrap.sh), so several
# look unused from inside this file — that's expected for a sourced lib.
# shellcheck disable=SC2034
[[ -n "${_CORE_UX_SH:-}" ]] && return 0
_CORE_UX_SH=1

# ── palette ───────────────────────────────────────────────────────────────────
# Colour ON only when stdout is a TTY (or CLICOLOR_FORCE) and NO_COLOR is unset
# (https://no-color.org), gated by UX_COLOR (auto|always|never) so a `--color WHEN` flag
# can re-evaluate it. Identical rule to scripts/lib/common.sh and zsh/ui.zsh — now in ONE
# place. Re-callable: change UX_COLOR / the env, call ux_palette again.
: "${UX_COLOR:=auto}"
ux_palette() {
  local on=0
  case "${UX_COLOR:-auto}" in
  always) on=1 ;;
  never) on=0 ;;
  *) { [[ -t 1 || -n "${CLICOLOR_FORCE:-}" ]]; } && on=1 ;;
  esac
  [[ -n "${NO_COLOR:-}" ]] && on=0
  if ((on)); then
    UX_GRN=$'\e[32m' UX_YEL=$'\e[33m' UX_RED=$'\e[31m' UX_BLU=$'\e[34m' UX_DIM=$'\e[2;37m' UX_RST=$'\e[0m'
  else
    UX_GRN='' UX_YEL='' UX_RED='' UX_BLU='' UX_DIM='' UX_RST=''
  fi
}
ux_palette

# ── glyphs ────────────────────────────────────────────────────────────────────
# Degrade to ASCII when the locale is NOT UTF-8 (a C/POSIX rescue shell renders the
# braille spinner + ✓/✗ marks as mojibake otherwise) — the same rule as zsh/ui.zsh and
# bootstrap.sh. bash 3.2-safe lowercasing via tr (no ${x,,}). UX_SPIN_FRAMES is a STRING
# of single-width frames, indexed per-char by ux_spin.
ux_glyphs() {
  local lc
  lc="$(printf '%s' "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" | tr '[:upper:]' '[:lower:]')"
  case "$lc" in
  *utf-8* | *utf8*) UX_OK='✓' UX_ERR='✗' UX_WARN='⚠' UX_INFO='•' UX_SPIN_FRAMES='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' ;;
  *) UX_OK='ok' UX_ERR='x' UX_WARN='!' UX_INFO='-' UX_SPIN_FRAMES='-\|/' ;;
  esac
}
ux_glyphs

ux_have() { command -v "$1" >/dev/null 2>&1; }

# ── spinner ───────────────────────────────────────────────────────────────────
# ux_spin <label> <cmd...> — run an opaque long step with a live spinner, returning the
# command's own exit status. Output is captured and shown ONLY on failure (a clean run
# stays quiet). On a non-TTY (CI, piped) it runs the command with output passing through
# and emits a scannable done/failed marker, so logs read as discrete steps. A Ctrl-C
# forwards SIGINT to the child, reaps it, restores the cursor, and returns 130 — the
# caller's own trap (e.g. bootstrap's on_interrupt) then takes over. Mirrors zsh/ui.zsh's
# _core_spin so the bash + zsh layers behave identically.
ux_spin() {
  local label="$1"
  shift
  (($#)) || return 0
  # No TTY → run plainly, mark the outcome.
  if [[ ! -t 1 ]]; then
    printf '  %s%s%s %s…\n' "$UX_YEL" "$UX_INFO" "$UX_RST" "$label"
    local rc=0
    "$@" || rc=$?
    if ((rc == 0)); then printf '  %s%s%s %s\n' "$UX_GRN" "$UX_OK" "$UX_RST" "$label"
    else printf '  %s%s%s %s — failed (exit %d)\n' "$UX_RED" "$UX_ERR" "$UX_RST" "$label" "$rc" >&2; fi
    return "$rc"
  fi
  local out rc
  out="$(mktemp -t ux-spin.XXXXXX)" || {
    "$@"
    return $?
  }
  "$@" >"$out" 2>&1 &
  local pid=$! frames="$UX_SPIN_FRAMES" i=0
  # Forward a signal to the child, reap it, restore the cursor, then return 130. SAVE the
  # caller's existing INT trap first and RESTORE it after (not a blind `trap - INT`), so a
  # caller with its own handler (e.g. bootstrap's on_interrupt) keeps it — the spinner
  # composes with an app-level trap instead of silently clearing it.
  local _prev_int
  _prev_int="$(trap -p INT)"
  trap 'kill -INT "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; printf "\e[?25h"; return 130' INT
  printf '\e[?25l' # hide cursor while spinning
  while kill -0 "$pid" 2>/dev/null; do
    printf '\r  %s%s%s %s' "$UX_YEL" "${frames:i++%${#frames}:1}" "$UX_RST" "$label"
    sleep 0.1
  done
  printf '\e[?25h\r\033[K' # restore cursor, column 0, clear line
  eval "${_prev_int:-trap - INT}" # restore the caller's prior INT trap (or clear if none)
  if wait "$pid"; then
    rc=0
    printf '  %s%s%s %s\n' "$UX_GRN" "$UX_OK" "$UX_RST" "$label"
  else
    rc=$?
    printf '  %s%s%s %s — failed (exit %d)\n' "$UX_RED" "$UX_ERR" "$UX_RST" "$label" "$rc" >&2
    sed 's/^/    /' "$out" >&2
  fi
  rm -f "$out"
  return "$rc"
}
