#!/usr/bin/env bash
# bin/audit-core.sh
# ──────────────────────────────────────────────────────────────────────────────
# THE AUDIT BUTTON — this repo's test suite.
#
# core.manifest calls itself "the contract. Audit scripts and the promotion
# checklist read it." This is that audit script. It verifies Core is internally
# consistent BEFORE it gets vendored (via bin/sync-core.sh) into all 9 OS repos,
# where a defect would fan out N-way.
#
# Checks (each is a section; a failure in one does not abort the others):
#   1. manifest <-> filesystem drift   — every manifest path exists; every
#                                         tracked Core file is listed or allowlisted
#   2. executable-bit assertions       — *.sh and bin/clip* must be +x in the
#                                         git index; zsh/*.zsh must NOT be (sourced)
#   3. shell syntax                     — bash -n on bash scripts; zsh -n on zsh modules
#   4. lua                              — luacheck nvim/        (if luacheck present)
#   5. lint                             — shellcheck            (if present)
#   6. config files                     — toml/yaml parse-check (if python3 present)
#   7. markdown                          — markdownlint (if markdownlint-cli2 present)
#   8. behavioral                       — load-order smoke + function units (test-core.sh)
#
# We deliberately do NOT enforce shfmt: the hand-tuned scripts here use an
# intentional compact one-liner style that shfmt would expand. shellcheck (real
# bugs) is enforced; formatting is left to .editorconfig + the author's eye.
#
# Graceful degradation (mirrors zsh/tools.zsh): a missing linter is SKIPPED with
# a notice, never a failure — so this runs on a bare box AND in CI, where the
# tools are installed. Exit status is non-zero only on a real FAIL.
#
# Usage:
#   ./bin/audit-core.sh            # run every section
#   ./bin/audit-core.sh --quiet    # only print SKIP/FAIL + the summary
# ──────────────────────────────────────────────────────────────────────────────
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

# Tracked files that live in dotfiles-core but are NOT vendored into OS repos'
# core/ subtree — repo-meta and dev tooling. Anything tracked, not matched by the
# manifest, must appear here (or under a META_PREFIXES dir) or section 1 flags it.
META_ALLOWLIST=(
  README.md PORTING-MATRIX.md CONTRIBUTING.md CHANGELOG.md LICENSE SECURITY.md
  core.manifest .gitignore .gitattributes .editorconfig .pre-commit-config.yaml .markdownlint.jsonc
  bin/sync-core.sh bin/audit-core.sh bin/test-core.sh bin/bench-core.sh
  Makefile
  nvim/.luacheckrc
  CODEOWNERS pull_request_template.md
)
# Directory prefixes whose tracked contents are allowlisted wholesale.
META_PREFIXES=(examples/ .github/)

# ── 1. manifest <-> filesystem drift ─────────────────────────────────────────
hdr "manifest ↔ filesystem"
# Parse manifest: strip comments/blank lines, take the first whitespace token.
# Use a read loop (not `mapfile`) — mapfile is bash 4+, and this gate must also
# run on macOS's stock bash 3.2 (the dotfiles-MacBook target / the macOS CI leg).
MANIFEST_PATHS=()
while IFS= read -r p; do
  MANIFEST_PATHS+=("$p")
done < <(sed -e 's/#.*//' -e 's/[[:space:]]*$//' core.manifest | awk 'NF {print $1}')
for p in "${MANIFEST_PATHS[@]}"; do
  if [[ "$p" == */ ]]; then
    if [[ -d "$p" ]]; then pass "dir  $p"; else fail "manifest lists missing dir:  $p"; fi
  else
    if [[ -e "$p" ]]; then pass "file $p"; else fail "manifest lists missing file: $p"; fi
  fi
done

# Reverse direction: tracked Core files not covered by the manifest or allowlist.
is_listed() { # $1 = path
  local f="$1" m pre
  for m in "${MANIFEST_PATHS[@]}"; do
    [[ "$f" == "$m" ]] && return 0                # exact file match
    [[ "$m" == */ && "$f" == "$m"* ]] && return 0 # under a listed dir
  done
  for m in "${META_ALLOWLIST[@]}"; do [[ "$f" == "$m" ]] && return 0; done
  for pre in "${META_PREFIXES[@]}"; do [[ "$f" == "$pre"* ]] && return 0; done
  return 1
}
if have git && git rev-parse --git-dir >/dev/null 2>&1; then
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    is_listed "$f" || fail "tracked file not in manifest/allowlist: $f"
  done < <(git ls-files)
  pass "reverse-drift scan complete (tracked files all accounted for)"
else
  skip "reverse-drift scan (not a git checkout)"
fi

# ── 2. executable-bit assertions ─────────────────────────────────────────────
hdr "executable bits"
if have git && git rev-parse --git-dir >/dev/null 2>&1; then
  while IFS= read -r line; do
    mode="${line%% *}"
    path="${line#* }"
    case "$path" in
    *.sh | bin/clip | bin/clip-paste)
      if [[ "$mode" == 100755 ]]; then
        pass "+x   $path"
      else fail "must be executable (100755), is $mode: $path"; fi
      ;;
    zsh/*.zsh)
      if [[ "$mode" == 100644 ]]; then
        pass "src  $path"
      else fail "sourced module must NOT be executable, is $mode: $path"; fi
      ;;
    esac
  done < <(git ls-files -s | awk '{print $1, $4}')
else
  skip "exec-bit check (not a git checkout)"
fi

# ── 3. shell syntax ──────────────────────────────────────────────────────────
hdr "shell syntax (bash -n / zsh -n)"
while IFS= read -r f; do
  if bash -n "$f" 2>/dev/null; then pass "bash -n $f"; else fail "bash syntax error: $f"; fi
done < <(git ls-files '*.sh' 'bin/clip' 'bin/clip-paste' 2>/dev/null)
if have zsh; then
  while IFS= read -r f; do
    if zsh -n "$f" 2>/dev/null; then pass "zsh -n  $f"; else fail "zsh syntax error: $f"; fi
  done < <(git ls-files 'zsh/*.zsh' 2>/dev/null)
else
  skip "zsh -n (zsh not installed)"
fi

# ── 4. lua ───────────────────────────────────────────────────────────────────
hdr "lua (luacheck)"
if have luacheck; then
  # luacheck discovers .luacheckrc by searching UP from the CWD, not the target —
  # so run it from inside nvim/, where nvim/.luacheckrc lives. From repo root it
  # would miss the config and emit hundreds of false "undefined vim" warnings.
  if (cd nvim && luacheck . --no-color >/dev/null 2>&1); then
    pass "luacheck nvim/"
  else
    fail "luacheck reported issues — run: (cd nvim && luacheck .)"
  fi
else
  skip "luacheck (not installed)"
fi

# ── 5. lint (shellcheck) ─────────────────────────────────────────────────────
hdr "lint (shellcheck)"
if have shellcheck; then
  sc_fail=0
  while IFS= read -r f; do
    shellcheck -x "$f" >/dev/null 2>&1 || {
      sc_fail=1
      fail "shellcheck: $f"
    }
  done < <(git ls-files '*.sh' 'bin/clip' 'bin/clip-paste' 2>/dev/null)
  ((sc_fail)) || pass "shellcheck (all bash scripts clean)"
else
  skip "shellcheck (not installed)"
fi

# ── 6. config files (toml / yaml parse) ──────────────────────────────────────
# A malformed starship.toml / mise config.toml / ci.yml is still valid *text* —
# so zsh -n and shellcheck never look at it — yet it breaks every one of the 9
# consumers at runtime (dead prompt, dead runtime manager, dead CI). Assert that
# every tracked TOML and YAML file actually PARSES. Best-effort + graceful skip,
# exactly like the linters above: TOML via python3 `tomllib` (stdlib since 3.11),
# YAML via python3 PyYAML when importable. pre-commit's check-toml/check-yaml are
# the hermetic author-time mirror of this same gate.
hdr "config files (toml / yaml)"
if have python3 && python3 -c 'import tomllib' 2>/dev/null; then
  while IFS= read -r f; do
    if python3 -c 'import tomllib,sys; tomllib.load(open(sys.argv[1],"rb"))' "$f" 2>/dev/null; then
      pass "toml $f"
    else fail "toml parse error: $f"; fi
  done < <(git ls-files '*.toml' 2>/dev/null)
else
  skip "toml parse (python3 tomllib unavailable — needs python ≥3.11)"
fi
if have python3 && python3 -c 'import yaml' 2>/dev/null; then
  while IFS= read -r f; do
    # safe_load_all: workflow/compose YAML can be multi-document (--- separators).
    if python3 -c 'import yaml,sys; list(yaml.safe_load_all(open(sys.argv[1])))' "$f" 2>/dev/null; then
      pass "yaml $f"
    else fail "yaml parse error: $f"; fi
  done < <(git ls-files '*.yml' '*.yaml' 2>/dev/null)
else
  skip "yaml parse (python3 PyYAML not importable)"
fi

# ── 7. markdown (markdownlint) ────────────────────────────────────────────────
# The docs ARE the deliverable on a public showcase repo, and they're the one file
# class shellcheck/zsh -n/toml-yaml never look at — so a leaked template tag or a
# broken heading ships unnoticed (it did: see CHANGELOG.md's history). markdownlint
# is the gate; .markdownlint.jsonc is the shared rule config (line-length off for
# the wide tables, everything structural on). Graceful skip when absent, exactly
# like the linters above; pre-commit's markdownlint-cli2 hook is the author-time
# mirror, and CI installs it so the gate actually runs there.
hdr "markdown (markdownlint)"
if have markdownlint-cli2; then
  if markdownlint-cli2 "**/*.md" >/dev/null 2>&1; then
    pass "markdownlint (all tracked markdown clean)"
  else
    fail "markdownlint reported issues — run: markdownlint-cli2 '**/*.md'"
  fi
else
  skip "markdownlint (markdownlint-cli2 not installed — npm i -g markdownlint-cli2)"
fi

# ── 8. behavioral tests (load-order smoke + function unit tests) ──────────────
# Static analysis above proves the modules PARSE; this proves they LOAD TOGETHER
# in canonical order and that the pure functions behave. Delegated to test-core.sh
# (single source of truth) but folded into ONE audit summary via CORE_TEST_NESTED.
# Self-gates on zsh: with none installed it SKIPs, exactly like sections 3–5.
hdr "behavioral (bin/test-core.sh)"
TEST_ARGS=()
((QUIET)) && TEST_ARGS=(--quiet)
if CORE_TEST_NESTED=1 ./bin/test-core.sh "${TEST_ARGS[@]}"; then
  pass "behavioral tests (load-order smoke + function units)"
else
  fail "behavioral tests failed — run: ./bin/test-core.sh"
fi

# ── summary ──────────────────────────────────────────────────────────────────
printf '\n%s──────── audit summary ────────%s\n' "$c_blu" "$c_rst"
printf '  %spass %d%s   %sskip %d%s   %sfail %d%s\n' \
  "$c_grn" "$PASS" "$c_rst" "$c_yel" "$SKIP" "$c_rst" "$c_red" "$FAIL" "$c_rst"
((FAIL == 0)) || {
  printf '%saudit FAILED%s\n' "$c_red" "$c_rst" >&2
  exit 1
}
printf '%saudit OK%s\n' "$c_grn" "$c_rst"
