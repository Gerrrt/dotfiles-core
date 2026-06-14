#!/usr/bin/env bash
# scripts/setup.sh — zero-config dev bootstrap for dotfiles-core (`make setup`).
# ──────────────────────────────────────────────────────────────────────────────
# Onboarding was implicit: a contributor had to read ci.yml, then hand-install the
# linters (luacheck, nvim, markdownlint, shellcheck) at the right pinned versions,
# then find `make hooks`. This does it in one command, reading the versions from the
# single source (scripts/tool-versions.env) so a local box matches CI:
#   1. install the pre-commit hooks (author-time mirror of CI)
#   2. doctor: report each linter's state against its pin
#   3. run the audit so the box is proven green before you start
#
# Best-effort + graceful, exactly like the other gate scripts: a missing tool is a
# SKIP with the install hint, never a hard stop. Safe to re-run (idempotent).
# ──────────────────────────────────────────────────────────────────────────────
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$HERE" || exit 1

# shellcheck source=scripts/lib/common.sh
source "${BASH_SOURCE[0]%/*}/lib/common.sh"

# Read a pinned version out of the single source (no `source`, so no shellcheck
# follow needed — mirrors how audit-core.sh reads the same file).
VERSIONS="scripts/tool-versions.env"
_ver() { sed -n "s/^$1=//p" "$VERSIONS" 2>/dev/null | head -n1; }

# ── 1. pre-commit hooks ───────────────────────────────────────────────────────
hdr "pre-commit hooks"
PRECOMMIT_VERSION="$(_ver PRECOMMIT_VERSION)"
if have pre-commit; then
  if pre-commit install >/dev/null 2>&1; then pass "pre-commit hooks installed"; else fail "pre-commit install failed"; fi
elif have pipx; then
  if pipx install "pre-commit==${PRECOMMIT_VERSION}" >/dev/null 2>&1 && pre-commit install >/dev/null 2>&1; then
    pass "pre-commit ${PRECOMMIT_VERSION} installed via pipx + hooks wired"
  else fail "pipx install pre-commit failed"; fi
else
  skip "pre-commit absent — install it: pipx install pre-commit==${PRECOMMIT_VERSION}"
fi

# ── 2. version doctor (present? vs the pin) ───────────────────────────────────
hdr "tool versions (pinned in $VERSIONS)"
_doctor() { # _doctor <bin> <pinned> <version-cmd...>
  local bin="$1" want="$2"
  shift 2
  if ! have "$bin"; then
    skip "$bin absent (CI pins $want) — see ci.yml for the install path"
    return
  fi
  # Each tool formats --version differently; pull the first semver-ish token.
  local got
  got="$("$@" 2>&1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)"
  if [[ -z "$got" ]]; then
    printf '%s⚠%s %s present, but its version string could not be parsed (pinned %s)\n' "$c_yel" "$c_rst" "$bin" "$want"
  elif [[ "$got" == "$want" ]]; then
    pass "$bin → $got   (matches pin)"
  else
    printf '%s⚠%s %s → %s does NOT match pinned %s — align with ci.yml to mirror CI\n' "$c_yel" "$c_rst" "$bin" "$got" "$want"
  fi
}
_doctor shellcheck "$(_ver SHELLCHECK_VERSION)" shellcheck --version
_doctor luacheck "$(_ver LUACHECK_VERSION)" luacheck --version
_doctor nvim "$(_ver NVIM_VERSION)" nvim --version
_doctor markdownlint-cli2 "$(_ver MARKDOWNLINT_VERSION)" markdownlint-cli2 --version
_doctor actionlint "$(_ver ACTIONLINT_VERSION)" actionlint --version
if have zsh; then pass "zsh → $(zsh --version | grep -oE '[0-9]+\.[0-9]+' | head -n1)"; else skip "zsh absent (the behavioral tests need it)"; fi
if have python3; then pass "python3 present (toml/yaml parse checks)"; else skip "python3 absent (toml/yaml checks skip)"; fi

# ── 3. prove the box green ────────────────────────────────────────────────────
hdr "running the audit"
if ./scripts/audit-core.sh --quiet; then
  printf '\n%s✓ setup complete — the audit is green. Run: make audit%s\n' "$c_grn" "$c_rst"
else
  printf '\n%s! setup finished, but the audit reported issues above — fix, then re-run.%s\n' "$c_yel" "$c_rst" >&2
  exit 1
fi
