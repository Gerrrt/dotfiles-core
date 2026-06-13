#!/usr/bin/env bash
# bin/test-core.sh
# ──────────────────────────────────────────────────────────────────────────────
# BEHAVIORAL tests for Core — the layer bin/audit-core.sh's static analysis can't
# reach. audit-core.sh proves the modules PARSE (zsh -n) and that the manifest and
# exec-bits are consistent; this proves the modules actually LOAD TOGETHER in the
# canonical order and that the pure shell functions DO what they claim. A defect
# here passes every per-file `zsh -n` cleanly and still fans out to 9 OS repos —
# which is exactly the gap this file closes.
#
# Two sections, both zsh-gated and degrading gracefully (mirrors audit-core.sh):
#   A. load-order smoke test  — source every zsh module in the README's canonical
#                               order inside ONE hermetic interactive zsh and
#                               assert the whole chain loads (catches cross-module
#                               contract breakage: a module that needs a var/fn an
#                               EARLIER module must define first).
#   B. function unit tests    — exercise the pure functions in functions.zsh
#                               (mkcd / cdup / mkbak / extract) and assert behavior.
#
# Hermetic: a throwaway $HOME/$ZDOTDIR/$XDG_CACHE_HOME is used, and the plugin dirs
# are pre-seeded EMPTY so plugins.zsh's first-run `git clone` is skipped — the test
# needs no network and writes nothing outside its tempdir.
#
# Graceful degradation: with no zsh installed (a bare box), both sections SKIP and
# the script exits 0 — identical philosophy to audit-core.sh, so this is safe to
# call from CI, pre-commit, and a developer's laptop alike.
#
# Usage:
#   ./bin/test-core.sh            # run every section
#   ./bin/test-core.sh --quiet    # only print SKIP/FAIL + the summary
# ──────────────────────────────────────────────────────────────────────────────

# This harness embeds zsh code as single-quoted literals on purpose: the `$…`
# inside them must be expanded by the zsh CHILD, not by this bash parent. SC2016
# (un-expanded `$` in single quotes) is therefore a false positive file-wide.
# shellcheck disable=SC2016
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$HERE" || exit 1

QUIET=0
[[ "${1:-}" == "--quiet" || "${1:-}" == "-q" ]] && QUIET=1

c_grn=$'\e[32m'
c_yel=$'\e[33m'
c_red=$'\e[31m'
c_blu=$'\e[34m'
c_rst=$'\e[0m'
PASS=0
SKIP=0
FAIL=0
pass() {
  PASS=$((PASS + 1))
  ((QUIET)) || printf '%s✓%s %s\n' "$c_grn" "$c_rst" "$*"
}
skip() {
  SKIP=$((SKIP + 1))
  printf '%s–%s %s\n' "$c_yel" "$c_rst" "$*"
}
fail() {
  FAIL=$((FAIL + 1))
  printf '%s✗%s %s\n' "$c_red" "$c_rst" "$*" >&2
}
hdr() { ((QUIET)) || printf '\n%s== %s ==%s\n' "$c_blu" "$*" "$c_rst"; }
have() { command -v "$1" >/dev/null 2>&1; }

# When invoked from audit-core.sh (CORE_TEST_NESTED=1) the audit owns the summary,
# so we suppress ours and only signal pass/fail via the exit code.
NESTED="${CORE_TEST_NESTED:-0}"
summary() {
  [[ "$NESTED" == 1 ]] && return 0
  printf '\n%s──────── test summary ────────%s\n' "$c_blu" "$c_rst"
  printf '  %spass %d%s   %sskip %d%s   %sfail %d%s\n' \
    "$c_grn" "$PASS" "$c_rst" "$c_yel" "$SKIP" "$c_rst" "$c_red" "$FAIL" "$c_rst"
}

# One throwaway sandbox for the whole run; clean it up no matter how we exit. It is
# created BEFORE the zsh gate because Section C (clipboard) is pure bash and must run
# even where zsh is absent — bin/clip's whole reason to exist is bare-box portability.
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/core-test.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT

# ── C. clipboard detection ladder (bin/clip / bin/clip-paste) ─────────────────
# bin/clip is the single highest-fan-out runtime artifact in Core — used by zsh
# (pbcopy alias), tmux (copy-pipe), AND nvim (clipboard provider), across all 9 OS
# repos — yet its WSL→macOS→Wayland→X11 ladder had no test, only `bash -n`. We drive
# the ladder HERMETICALLY: PATH is pointed at a fake bin holding a stub `uname` that
# reports the OS we want, a stub `grep` that answers the /proc/version probe, and
# stub backends that print a marker instead of touching a real clipboard — then we
# assert the RIGHT backend was exec'd. PATH is the fake dir ONLY (a real `bash`
# symlink keeps the `#!/usr/bin/env bash` shebang resolvable), so backend probing is
# fully deterministic regardless of what the host happens to have installed. Pure
# bash — runs with no zsh, exactly where bin/clip most needs to work.
hdr "clipboard detection ladder (bin/clip, bin/clip-paste)"
CLIP="$HERE/bin/clip"
CLIPPASTE="$HERE/bin/clip-paste"
CBIN="$SANDBOX/clipbin"
_real_bash="$(command -v bash)"
_real_tr="$(command -v tr)"

_stub() { printf '#!/bin/sh\n%s\n' "$2" >"$CBIN/$1"; chmod +x "$CBIN/$1"; }
# Fresh fake bin + cleared env before each scenario. `bash` is symlinked so the
# shebang resolves under the stripped PATH; `uname`/`grep` default to "Linux, not
# WSL" and Darwin/WSL cases override them.
_clip_reset() {
  rm -rf "$CBIN"; mkdir -p "$CBIN"
  unset WSL_DISTRO_NAME WAYLAND_DISPLAY
  ln -s "$_real_bash" "$CBIN/bash"
  _stub uname 'echo Linux'
  _stub grep 'exit 1'
}
# Assert prog's stdout is exactly the marker the chosen backend prints.
_clip_is() { # _clip_is <label> <prog> <expected>
  local out
  out="$(printf 'payload' | PATH="$CBIN" "$2" 2>/dev/null)"
  if [[ "$out" == "$3" ]]; then pass "$1"; else fail "$1 (got '${out}', want '${3}')"; fi
}
# Assert prog exits non-zero — the no-backend-found path.
_clip_fails() { # _clip_fails <label> <prog>
  if printf 'payload' | PATH="$CBIN" "$2" >/dev/null 2>&1; then
    fail "$1 (expected non-zero exit)"
  else pass "$1"; fi
}

# clip (copy) — each scenario leaves ONLY the intended backend reachable.
_clip_reset; export WSL_DISTRO_NAME=Ubuntu; _stub clip.exe 'echo WSL'
_clip_is "clip → clip.exe when WSL_DISTRO_NAME set" "$CLIP" WSL
unset WSL_DISTRO_NAME
_clip_reset; _stub uname 'echo Darwin'; _stub pbcopy 'echo MAC'
_clip_is "clip → pbcopy on Darwin" "$CLIP" MAC
_clip_reset; export WAYLAND_DISPLAY=wayland-0; _stub wl-copy 'echo WL'
_clip_is "clip → wl-copy under Wayland" "$CLIP" WL
unset WAYLAND_DISPLAY
_clip_reset; _stub xclip 'echo XCLIP'
_clip_is "clip → xclip on X11" "$CLIP" XCLIP
_clip_reset; _stub xsel 'echo XSEL'
_clip_is "clip → xsel when xclip absent" "$CLIP" XSEL
_clip_reset
_clip_fails "clip exits non-zero with no backend" "$CLIP"

# clip-paste (paste) — mirror ladder; the WSL leg also strips the CR powershell adds.
_clip_reset; export WSL_DISTRO_NAME=Ubuntu; ln -s "$_real_tr" "$CBIN/tr"
_stub powershell.exe 'printf "WSLPASTE\r"'
_clip_is "clip-paste → powershell + CR-strip on WSL" "$CLIPPASTE" WSLPASTE
unset WSL_DISTRO_NAME
_clip_reset; _stub uname 'echo Darwin'; _stub pbpaste 'echo MAC'
_clip_is "clip-paste → pbpaste on Darwin" "$CLIPPASTE" MAC
_clip_reset; export WAYLAND_DISPLAY=wayland-0; _stub wl-paste 'echo WL'
_clip_is "clip-paste → wl-paste under Wayland" "$CLIPPASTE" WL
unset WAYLAND_DISPLAY
_clip_reset; _stub xclip 'echo XCLIP'
_clip_is "clip-paste → xclip -o on X11" "$CLIPPASTE" XCLIP
_clip_reset
_clip_fails "clip-paste exits non-zero with no backend" "$CLIPPASTE"

# ── zsh-gated sections (A load-order, B function units) ───────────────────────
# Everything below needs a real zsh. On a bare box we SKIP it (not fail) and fall
# through to the shared summary, so a Section-C failure still surfaces as exit 1.
if ! have zsh; then
  hdr "zsh behavioral sections (load-order + function units)"
  skip "load-order smoke + function units (zsh not installed — runs in CI)"
  summary
  ((FAIL == 0)) || {
    [[ "$NESTED" == 1 ]] || printf '%stests FAILED%s\n' "$c_red" "$c_rst" >&2
    exit 1
  }
  [[ "$NESTED" == 1 ]] || printf '%stests OK%s\n' "$c_grn" "$c_rst"
  exit 0
fi

# ── A. load-order smoke test ──────────────────────────────────────────────────
hdr "load-order smoke test (canonical .zshrc chain)"
# The README/manifest canonical order. There is no os/local module here — those
# are supplied by each OS repo's loader and are out of Core's scope.
CORE_MODULES=(tools options history aliases git functions fzf bindings plugins op maint update)

# Pre-seed empty plugin dirs so plugins.zsh's first-run clone is a no-op (hermetic,
# no network). _zplugin_load finds the dir, skips the clone, finds no source file,
# and moves on — exercising the load-order logic without pulling from GitHub.
mkdir -p "$SANDBOX/zdot/plugins"
for plug in zsh-defer zsh-vi-mode zsh-history-substring-search \
  zsh-autosuggestions fast-syntax-highlighting fzf-tab zsh-you-should-use; do
  mkdir -p "$SANDBOX/zdot/plugins/$plug"
done

# Generate the sandbox .zshrc: source every Core module in canonical order, then
# print a sentinel. We deliberately do NOT key success on each module's exit code —
# a module whose LAST statement is a false guard (e.g. aliases.zsh ends on
# `[[ -n $HAVE_GPING ]] && alias ping=gping`, false on a bare box) returns non-zero
# while having loaded perfectly. The real signal of a broken load-order contract is
# a RUNTIME error on stderr (a module using a fn/widget/var an EARLIER module must
# define first) — so we assert: the chain REACHED THE END (sentinel) with CLEAN
# stderr. Parse errors are already caught per-file by audit-core.sh's `zsh -n`.
export CORE_DIR="$HERE/zsh"
{
  printf 'for _m in %s; do source "$CORE_DIR/$_m.zsh"; done\n' "${CORE_MODULES[*]}"
  printf 'print -r -- "SMOKE_OK"\n'
} >"$SANDBOX/zdot/.zshrc"

# Run one interactive zsh with the sandbox as HOME + ZDOTDIR. -i so the modules'
# `[[ $- == *i* ]]` guards pass and the interactive paths actually execute.
smoke_out="$(
  HOME="$SANDBOX" ZDOTDIR="$SANDBOX/zdot" \
    XDG_CACHE_HOME="$SANDBOX/cache" XDG_STATE_HOME="$SANDBOX/state" \
    XDG_RUNTIME_DIR="$SANDBOX/run" CORE_DIR="$CORE_DIR" \
    zsh -i -c exit 2>"$SANDBOX/smoke.err"
)"
# High-signal zsh runtime-error markers — what a real load-order break looks like.
smoke_errs="$(grep -Ei \
  'command not found|parse error|: no such file or directory|not defined|bad pattern|bad math expression|maximum nested' \
  "$SANDBOX/smoke.err" 2>/dev/null || true)"
if ! printf '%s' "$smoke_out" | grep -q '^SMOKE_OK$'; then
  fail "load-order chain did not reach the end (no SMOKE_OK sentinel — a module aborted)"
  [[ -s "$SANDBOX/smoke.err" ]] && sed 's/^/    /' "$SANDBOX/smoke.err" >&2
elif [[ -n "$smoke_errs" ]]; then
  fail "runtime errors during canonical load (load-order contract broken):"
  printf '%s\n' "$smoke_errs" | sed 's/^/    /' >&2
else
  pass "all ${#CORE_MODULES[@]} modules loaded in canonical order (clean stderr)"
fi

# ── B. function unit tests ────────────────────────────────────────────────────
hdr "function unit tests (functions.zsh)"
FN="$HERE/zsh/functions.zsh"

# Run an assertion under zsh; $1 = label, $2 = zsh body that must exit 0.
check() { # check <label> <zsh-body>
  if HOME="$SANDBOX" zsh -fc "source '$FN' || exit 1; $2" >/dev/null 2>&1; then
    pass "$1"
  else
    fail "$1"
  fi
}

# Like check, but SKIP (not fail) when a required external tool is absent — so the
# archive round-trip tests degrade gracefully on a bare box, mirroring the linter
# skips above. extract's own first branch is `ouch` when HAVE_OUCH is set; under
# `zsh -fc` that var is unset, so these exercise the hand-rolled case fallback.
check_dep() { # check_dep <label> <dep> <zsh-body>
  if ! have "$2"; then
    skip "$1 ($2 not installed)"
    return
  fi
  if HOME="$SANDBOX" zsh -fc "source '$FN' || exit 1; $3" >/dev/null 2>&1; then
    pass "$1"
  else
    fail "$1"
  fi
}

check "mkcd creates and enters a nested dir" \
  'd=$(mktemp -d); cd "$d"; mkcd a/b/c; [[ ${PWD:t} == c && -d "$d/a/b/c" ]]'
check "cdup climbs N directories" \
  'd=$(mktemp -d); mkdir -p "$d/a/b/c"; cd "$d/a/b/c"; cdup 2; [[ ${PWD:t} == a ]]'
check "mkbak writes a timestamped .bak copy" \
  'd=$(mktemp -d); cd "$d"; print hi > f; mkbak f; set -- f.*.bak; [[ -f $1 ]]'
check "mkbak's .bak is byte-identical to the original" \
  'd=$(mktemp -d); cd "$d"; print -r -- payload > f; mkbak f; set -- f.*.bak; [[ -f $1 && "$(cat -- $1)" == payload ]]'
check "extract rejects a non-existent file" \
  'extract /no/such/archive.tar.gz; (( $? != 0 ))'
check "extract rejects a known file of unknown format" \
  'd=$(mktemp -d); cd "$d"; : > mystery.qqq; extract mystery.qqq; (( $? != 0 ))'
check_dep "extract round-trips a .tar.gz" tar \
  'd=$(mktemp -d); cd "$d"; mkdir src; print -r -- hi > src/a.txt; tar czf a.tgz src; rm -rf src; extract a.tgz; [[ -f src/a.txt && "$(cat -- src/a.txt)" == hi ]]'
check_dep "extract round-trips a .gz" gzip \
  'd=$(mktemp -d); cd "$d"; print -r -- hi > f.txt; gzip f.txt; extract f.txt.gz; [[ -f f.txt && "$(cat -- f.txt)" == hi ]]'

# ── summary ───────────────────────────────────────────────────────────────────
summary
((FAIL == 0)) || {
  [[ "$NESTED" == 1 ]] || printf '%stests FAILED%s\n' "$c_red" "$c_rst" >&2
  exit 1
}
[[ "$NESTED" == 1 ]] || printf '%stests OK%s\n' "$c_grn" "$c_rst"
