# shellcheck shell=bash
# scripts/lib/common.sh — shared output helpers for the gate scripts.
# ──────────────────────────────────────────────────────────────────────────────
# ONE definition of the colour palette + pass/skip/fail/hdr/have that
# audit-core.sh, test-core.sh, bench-core.sh, sync-core.sh and update-plugins.sh
# all need — replacing five copy-pasted ~15-line blocks that could (and did) drift.
#
# This is a SOURCED library, not a runnable script — so, exactly like zsh/*.zsh, it
# carries NO shebang and stays mode 100644 (the audit's exec-bit section asserts
# this: scripts/lib/*.sh is the bash sibling of the sourced zsh modules). The
# `# shellcheck shell=bash` directive above keeps the linter in bash mode without a
# shebang. bash 3.2-safe (no associative arrays / mapfile) so it runs on macOS too.
#
# Usage (from any scripts/*.sh):
#   source "${BASH_SOURCE[0]%/*}/lib/common.sh"
# ──────────────────────────────────────────────────────────────────────────────

# Idempotent: a second source is a no-op (a script + the audit both sourcing it,
# or future nesting, must not redefine or re-zero the counters).
[[ -n "${_CORE_COMMON_SH:-}" ]] && return 0
_CORE_COMMON_SH=1

# Palette. Emitted unconditionally (these scripts have always coloured their
# output; CI logs render or strip it). Kept here so the codes live in one place.
c_grn=$'\e[32m'
c_yel=$'\e[33m'
c_red=$'\e[31m'
c_blu=$'\e[34m'
c_rst=$'\e[0m'

# Tallies + quiet flag. Initialised with `:=` so a caller that runs under `set -u`
# (all of them) never trips an unbound-variable error on the first pass()/skip().
# A script that doesn't count (sync/update-plugins) simply ignores the totals.
: "${QUIET:=0}"
: "${PASS:=0}"
: "${SKIP:=0}"
: "${FAIL:=0}"

have() { command -v "$1" >/dev/null 2>&1; }

# pass/skip/fail keep a running tally; hdr prints a section banner. `((QUIET))` is
# always guarded by `|| …` so it can't abort a caller that runs under `set -e`
# (a bare `((0))` returns status 1).
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
