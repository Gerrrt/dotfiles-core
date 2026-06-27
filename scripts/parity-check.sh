#!/usr/bin/env bash
# scripts/parity-check.sh
# ──────────────────────────────────────────────────────────────────────────────
# Enforce the `aligned` rows of PARITY.md across the two interactive shells: zsh
# (Core, this repo) and PowerShell (the dotfiles-Windows host layer). PARITY.md is
# the human contract; this is the machine gate that fails when an `aligned`
# capability silently drifts out of one shell — e.g. someone drops the fzf
# tokyonight palette from pwsh, re-opening exactly the divergence we just closed.
#
# Cross-repo (like fleet-drift.sh): pwsh lives in a SEPARATE repo that doesn't
# vendor Core, so we read it from a sibling checkout. Graceful degradation mirrors
# audit-core.sh: if dotfiles-Windows isn't checked out, the pwsh side is SKIPPED
# with a notice (not failed) unless --strict — so this still runs green in a
# Core-only clone, and the scheduled workflow clones Windows first.
#
# Each check asserts a distinctive needle is present in BOTH a zsh source and a
# pwsh source. Keep these in step with PARITY.md: when a row there becomes
# `aligned`, add a check here; the check IS the enforcement.
#
# Usage:
#   ./scripts/parity-check.sh                 # check against sibling dotfiles-Windows
#   ./scripts/parity-check.sh --root ~/src    # the fleet lives elsewhere
#   ./scripts/parity-check.sh --strict        # a not-checked-out Windows repo FAILS
#
# Exit: 0 = every aligned row holds (or pwsh skipped); 1 = drift; 2 = usage error.
# ──────────────────────────────────────────────────────────────────────────────
set -uo pipefail

HERE="$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$HERE/scripts/lib/common.sh"

ROOT="$(cd "$HERE/.." && pwd)" # siblings of dotfiles-core by default
[[ -n "${DOTFILES_ROOT:-}" ]] && ROOT="$DOTFILES_ROOT"
STRICT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
  --root)
    ROOT="${2:-}"
    shift 2 || { fail "--root needs a directory"; exit 2; }
    ;;
  --strict) STRICT=1; shift ;;
  --quiet) QUIET=1; shift ;;
  --color)
    _core_set_color "${2:-}" || { fail "--color wants auto|always|never"; exit 2; }
    shift 2
    ;;
  -h | --help)
    sed -n '2,/^set -u/p' "${BASH_SOURCE[0]}" | sed '$d;s/^# \{0,1\}//'
    exit 0
    ;;
  *) fail "unknown argument: $1"; exit 2 ;;
  esac
done

[[ -d "$ROOT" ]] || { fail "fleet root not found: $ROOT"; exit 2; }
WIN="$ROOT/dotfiles-Windows"

# Each row: label | zsh-relpath | zsh-needle | pwsh-relpath | pwsh-needle.
# Needles are FIXED strings (grep -F), chosen distinctive enough to avoid false hits.
# Mirrors PARITY.md's `aligned` rows; the fzf-palette row guards the parity fix that
# closed the first row. (Keybinding rows stay out until the open decisions are made.)
CHECKS=(
  "prompt: starship|zsh/tools.zsh|starship init|powershell/core/10-tools.ps1|starship init"
  "smart cd: zoxide|zsh/tools.zsh|zoxide init|powershell/core/10-tools.ps1|zoxide init"
  "history: atuin|zsh/tools.zsh|atuin init|powershell/core/10-tools.ps1|atuin init"
  "fzf tokyonight palette|zsh/fzf.zsh|query:#c0caf5:regular|powershell/core/10-tools.ps1|query:#c0caf5:regular"
  "fzf default command (fd)|zsh/fzf.zsh|fd --type f|powershell/core/10-tools.ps1|fd --type f"
)

# _has <file> <needle> — fixed-string presence test; non-zero if file missing too.
_has() { [[ -r "$1" ]] && grep -qF -- "$2" "$1"; }

hdr "Cross-shell parity (PARITY.md aligned rows)"

DRIFT=0
WIN_PRESENT=1
if [[ ! -d "$WIN" ]]; then
  WIN_PRESENT=0
  if ((STRICT)); then
    fail "dotfiles-Windows not checked out at $WIN (--strict)"
    DRIFT=1
  else
    skip "dotfiles-Windows not checked out at $WIN — pwsh side not verified"
  fi
fi
for _row in "${CHECKS[@]}"; do
  IFS='|' read -r label zfile zneedle pfile pneedle <<<"$_row"
  # zsh side (always checked — this is the Core repo)
  if _has "$HERE/$zfile" "$zneedle"; then
    pass "$label — zsh ($zfile)"
  else
    fail "$label — MISSING from zsh ($zfile): '$zneedle'"
    DRIFT=1
  fi
  # pwsh side (only when the Windows repo is present)
  ((WIN_PRESENT)) || continue
  if _has "$WIN/$pfile" "$pneedle"; then
    pass "$label — pwsh ($pfile)"
  else
    fail "$label — MISSING from pwsh ($pfile): '$pneedle'"
    DRIFT=1
  fi
done

echo
if ((DRIFT)); then
  fail "cross-shell parity drift — an aligned PARITY.md row is missing from a shell"
  exit 1
fi
if ((WIN_PRESENT)); then
  pass "all aligned rows hold across zsh + pwsh"
else
  pass "all aligned rows hold on zsh (pwsh side skipped — clone dotfiles-Windows to verify)"
fi
exit 0
