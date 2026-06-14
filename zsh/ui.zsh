# core/zsh/ui.zsh
# ──────────────────────────────────────────────────────────────────────────────
# Shared terminal-UX primitives for Core's interactive commands — one consistent
# voice for errors, hints, confirms, and progress, so functions.zsh / op.zsh /
# update.zsh / maint.zsh / plugins.zsh stop hand-rolling ad-hoc `echo "Usage: …"`
# lines. The dev-tooling scripts already have this polish (scripts/lib/common.sh);
# this is its runtime, end-user counterpart.
#
# gum-aware, with a plain fallback on every helper, so a bare box (fresh server,
# rescue shell) degrades to readable text instead of erroring. gum is detected
# live (`command -v`), NOT via tools.zsh's HAVE_GUM — these helpers must also work
# under the function unit tests, which source this file ALONE in a `zsh -fc`.
#
# LOAD ORDER: source EARLY, right after tools.zsh — every later module may call it.
# Deliberately NOT interactivity-guarded (no `[[ $- == *i* ]] || return`): it only
# DEFINES functions, and the unit tests source it non-interactively.
# ──────────────────────────────────────────────────────────────────────────────

# Palette. Colour is applied only when stderr is a TTY and NO_COLOR is unset, so
# captured/piped output (the unit tests grep stderr) stays plain. Glyphs match the
# repo's existing ✓/–/✗ idiom (scripts/lib/common.sh, the update.zsh nudge).
typeset -g _CORE_C_RED=$'\e[31m' _CORE_C_YEL=$'\e[33m' _CORE_C_GRN=$'\e[32m'
typeset -g _CORE_C_DIM=$'\e[2;37m' _CORE_C_RST=$'\e[0m'

_core_have() { command -v "$1" >/dev/null 2>&1; }
# Colourise fd $1 (default 2 = stderr)? The fd must be a terminal AND NO_COLOR
# unset (https://no-color.org). Each helper asks about the stream it ACTUALLY
# writes to — _core_ok (stdout) passes 1, the stderr helpers use the default 2 —
# so `cmd | cat` (stdout piped, stderr still a TTY) never leaks colour into the pipe.
_core_color() { [[ -t ${1:-2} && -z ${NO_COLOR:-} ]]; }

# ── messages ──────────────────────────────────────────────────────────────────
# err/warn/hint/usage go to STDERR (diagnostics, never pollute a captured stdout);
# ok goes to STDOUT (it's a result). None of them exits — a zsh helper that called
# `exit` would kill the user's interactive shell. Callers do `_core_err …; return 1`.
_core_ok() { # success line → stdout (so it checks fd 1, not fd 2)
  if _core_color 1; then print -r -- "${_CORE_C_GRN}✓${_CORE_C_RST} $*"
  else print -r -- "✓ $*"; fi
}
_core_err() { # error line → stderr
  if _core_color; then print -u2 -r -- "${_CORE_C_RED}✗${_CORE_C_RST} $*"
  else print -u2 -r -- "✗ $*"; fi
}
_core_warn() { # warning line → stderr
  if _core_color; then print -u2 -r -- "${_CORE_C_YEL}⚠${_CORE_C_RST} $*"
  else print -u2 -r -- "⚠ $*"; fi
}
_core_hint() { # dim follow-up "hint:" line → stderr (the fix, after an error)
  if _core_color; then print -u2 -r -- "${_CORE_C_DIM}  hint: $*${_CORE_C_RST}"
  else print -u2 -r -- "  hint: $*"; fi
}
_core_usage() { # "usage: …" → stderr
  if _core_color; then print -u2 -r -- "${_CORE_C_DIM}usage:${_CORE_C_RST} $*"
  else print -u2 -r -- "usage: $*"; fi
}

# ── confirm ───────────────────────────────────────────────────────────────────
# _core_confirm <prompt>  → 0 = yes, non-zero = no. Defensive by default: with no
# controlling TTY (a pipe, a cron job, a captured run) it DECLINES rather than
# blocking or assuming yes — so wrapping a destructive action in it is fail-safe.
# gum confirm when present (arrow-key UI); else a one-keystroke `read -q`.
_core_confirm() {
  local prompt="${1:-Proceed?}"
  [[ -t 0 && -t 2 ]] || return 1 # no TTY → safe "no"
  if _core_have gum; then
    gum confirm "$prompt"
  else
    local reply
    read -q "reply?${prompt} [y/N] "
    local rc=$?
    print -u2 -- '' # newline after the single-char read
    return $rc
  fi
}

# ── progress ──────────────────────────────────────────────────────────────────
# _core_spin <title> <cmd...>  → run cmd while showing a spinner; return cmd's
# exit code. Non-TTY → just runs it (no animation bytes in logs/pipes). gum spin
# when present; else a hand-rolled braille spinner. `nomonitor` silences the
# job-control "[1] <pid>" / "done" chatter the background job would otherwise emit.
_core_spin() {
  local title="$1"
  shift
  (($#)) || return 0
  if [[ ! -t 2 ]]; then "$@"; return; fi
  if _core_have gum; then
    gum spin --spinner dot --title "$title" --show-error -- "$@"
    return
  fi
  # localtraps scopes the INT trap below to THIS function; nomonitor silences the
  # job-control "[1] <pid>"/"done" chatter the background job would otherwise emit.
  setopt localoptions localtraps nomonitor
  local -a fr=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  printf '\e[?25l' >&2 # hide the cursor so it doesn't blink ON TOP of the glyph
  "$@" &
  local pid=$!
  # Ctrl-C during the spin would otherwise kill the loop mid-frame and leave a frozen
  # glyph + a HIDDEN cursor behind. Trap it: stop the job, clear the line, restore the
  # cursor, and propagate as 130 (128+SIGINT) so callers can tell it was interrupted.
  trap 'kill "$pid" 2>/dev/null; printf "\r\e[K\e[?25h" >&2; return 130' INT
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf '\r%s %s' "${fr[$((i % 10 + 1))]}" "$title" >&2
    sleep 0.1
    ((i++))
  done
  wait "$pid"
  local rc=$?
  printf '\r\e[K\e[?25h' >&2 # clear the spinner line + restore the cursor
  return $rc
}
