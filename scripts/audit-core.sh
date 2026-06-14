#!/usr/bin/env bash
# scripts/audit-core.sh
# ──────────────────────────────────────────────────────────────────────────────
# THE AUDIT BUTTON — this repo's test suite.
#
# core.manifest calls itself "the contract. Audit scripts and the promotion
# checklist read it." This is that audit script. It verifies Core is internally
# consistent BEFORE it gets vendored (via scripts/sync-core.sh) into all 9 OS repos,
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
#   8. workflows                         — actionlint on .github/workflows (if present)
#   9. version consistency              — pre-commit hook revs == tool-versions.env
#  10. behavioral                       — load-order smoke + function units (test-core.sh)
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
#   ./scripts/audit-core.sh            # run every section
#   ./scripts/audit-core.sh --quiet    # only print SKIP/FAIL + the summary
# ──────────────────────────────────────────────────────────────────────────────
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$HERE" || exit 1

QUIET=0
# Scope gates the SLOW, area-specific sections so a per-area push (driven by
# scripts/ci-classify.sh) pays only for what it changed — e.g. a docs-only PR runs
# the cheap structural/config/markdown checks but skips the zsh and nvim toolchains.
# FAIL-CLOSED default: with no --scope, BOTH areas run (full audit), so a local
# `make audit`, pre-commit, and an un-classified push are never silently narrowed.
# Only ci.yml passes an explicit, classifier-derived --scope. The cheap, cross-cutting
# checks (manifest, exec-bits, toml/yaml/json, markdown, workflows, version) ALWAYS run.
SCOPE_SHELL=1
SCOPE_NVIM=1
_set_scope() { # _set_scope <comma-list: shell,nvim | all | none>
  SCOPE_SHELL=0
  SCOPE_NVIM=0
  local tok
  local IFS=,
  for tok in $1; do
    case "$tok" in
    shell) SCOPE_SHELL=1 ;;
    nvim) SCOPE_NVIM=1 ;;
    all | full)
      SCOPE_SHELL=1
      SCOPE_NVIM=1
      ;;
    none | "") ;;
    *) # unknown token → run EVERYTHING (fail-safe), matching ci.yml's safe default
      printf 'audit-core.sh: unknown scope %s — running full (fail-safe)\n' "$tok" >&2
      SCOPE_SHELL=1
      SCOPE_NVIM=1
      ;;
    esac
  done
}
# Render the active scope as test-core.sh expects it (shell,nvim | shell | nvim | none).
_scope_str() {
  local s=""
  ((SCOPE_SHELL)) && s="shell"
  ((SCOPE_NVIM)) && s="${s:+$s,}nvim"
  printf '%s' "${s:-none}"
}

# Parse EVERY argument (not just $1), so an unknown flag OR a stray extra operand is
# REJECTED with a hint rather than silently ignored — `audit-core.sh --quiet extra`
# or a typo like `--hepl` used to slip through and just run the full audit, masking it.
# -h/--help prints usage and exits clean.
while (($#)); do
  case "$1" in
  -q | --quiet) QUIET=1 ;;
  --scope)
    shift
    _set_scope "${1:-}"
    ;;
  --scope=*) _set_scope "${1#*=}" ;;
  -h | --help)
    cat <<'EOF'
usage: audit-core.sh [-q|--quiet] [--scope LIST] [-h|--help]

THE audit button — manifest/exec-bit/syntax/lint/config/markdown/workflow/
version/behavioral checks. CI and pre-commit run this exact script.

  -q, --quiet     only print SKIP/FAIL lines and the final summary
  --scope LIST    limit the slow area-specific sections to a comma list:
                  shell, nvim, all (default), none. Cheap structural/config/
                  markdown/workflow/version checks always run. CI sets this from
                  scripts/ci-classify.sh; omit it locally to run the full audit.
  -h, --help      show this help and exit
EOF
    exit 0
    ;;
  *)
    printf 'audit-core.sh: unexpected argument: %s\n' "$1" >&2
    printf 'try: audit-core.sh --help\n' >&2
    exit 2
    ;;
  esac
  shift
done

# Shared palette + pass/skip/fail/hdr/have (one definition for every gate script).
# Sourced AFTER QUIET is set so the lib's `: "${QUIET:=0}"` preserves it.
# shellcheck source=scripts/lib/common.sh
source "${BASH_SOURCE[0]%/*}/lib/common.sh"

# Tracked files that live in dotfiles-core but are NOT vendored into OS repos'
# core/ subtree — repo-meta and dev tooling. Anything tracked, not matched by the
# manifest, must appear here (or under a META_PREFIXES dir) or section 1 flags it.
META_ALLOWLIST=(
  README.md PORTING-MATRIX.md CONTRIBUTING.md CHANGELOG.md LICENSE SECURITY.md
  core.manifest .gitignore .gitattributes .editorconfig .pre-commit-config.yaml .markdownlint.jsonc
  Makefile
  nvim/.luacheckrc
  CODEOWNERS pull_request_template.md
)
# Directory prefixes whose tracked contents are allowlisted wholesale. scripts/ is
# this repo's DEV TOOLING (audit/test/bench/sync/update-plugins) — the gate scripts
# themselves, never vendored into an OS repo (only bin/clip* + the manifest paths
# are). Listing the dir, not each script, means a new dev tool is covered the moment
# it lands here — the bin/-vs-scripts/ split is exactly what makes that unambiguous.
META_PREFIXES=(examples/ .github/ scripts/)

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
    scripts/lib/*.sh)
      # Sourced bash libraries — the bash sibling of zsh/*.zsh: no shebang, NOT
      # executable. Must precede the generic *.sh arm below (case matches first).
      if [[ "$mode" == 100644 ]]; then
        pass "src  $path"
      else fail "sourced lib must NOT be executable, is $mode: $path"; fi
      ;;
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
if ((SCOPE_SHELL)); then
  if have zsh; then
    # The sourced modules AND the autoloaded completion functions (zsh/completions/_*,
    # no .zsh extension) — both are zsh that fans out to 9 repos; both must parse.
    while IFS= read -r f; do
      if zsh -n "$f" 2>/dev/null; then pass "zsh -n  $f"; else fail "zsh syntax error: $f"; fi
    done < <(git ls-files 'zsh/*.zsh' 'zsh/completions/*' 2>/dev/null)
  else
    skip "zsh -n (zsh not installed)"
  fi
else
  skip "zsh -n (out of scope)"
fi

# ── 4. lua ───────────────────────────────────────────────────────────────────
hdr "lua (luacheck)"
if ! ((SCOPE_NVIM)); then
  skip "luacheck (out of scope)"
elif have luacheck; then
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
if ! ((SCOPE_SHELL)); then
  skip "shellcheck (out of scope)"
elif have shellcheck; then
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
# JSON: nvim/lazy-lock.json pins every Neovim plugin's commit for a reproducible
# editor across the 9 repos — a truncated/corrupt lock breaks `:Lazy restore` for
# all of them, and like the toml/yaml above it's valid *text* the other gates skip.
# `*.json` (not `*.jsonc`) so the JSONC config files keep their comments. json is in
# the stdlib, so this only needs python3 — no extra import gate like PyYAML.
if have python3; then
  while IFS= read -r f; do
    if python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$f" 2>/dev/null; then
      pass "json $f"
    else fail "json parse error: $f"; fi
  done < <(git ls-files '*.json' 2>/dev/null)
else
  skip "json parse (python3 unavailable)"
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

# ── 8. workflows (actionlint) ─────────────────────────────────────────────────
# .github/workflows/*.yml is a fan-out artifact with no gate of its own: the YAML
# parse in section 6 proves it's well-formed text, not that the workflow is VALID —
# a bad `needs:`, an undefined job output, or a shellcheck error inside a run: block
# all parse as YAML and still break CI for every push. actionlint catches those (and
# runs shellcheck on the run: scripts). Graceful skip when absent, like every linter
# above; CI installs it pinned (ACTIONLINT_VERSION) so the gate actually runs there.
hdr "workflows (actionlint)"
if have actionlint; then
  if actionlint >/dev/null 2>&1; then
    pass "actionlint (workflows valid)"
  else
    fail "actionlint reported issues — run: actionlint"
  fi
else
  skip "actionlint (not installed — go install github.com/rhysd/actionlint/cmd/actionlint@latest)"
fi

# ── 9. version consistency (tool-versions.env ↔ .pre-commit-config.yaml) ──────
# scripts/tool-versions.env is the SINGLE SOURCE for the pinned dev-tool versions.
# CI loads it directly (no literals left in ci.yml), but .pre-commit-config.yaml is
# static YAML that can't read it — so the hook `rev:` fields are the one place a pin
# can still drift. Gate them: assert each hook rev equals its version here. A bump in
# one place without the other fails the audit instead of silently shipping mismatched
# author-time vs CI tooling. Pure bash + awk (busybox-safe); skips if either is gone.
hdr "version consistency (tool-versions.env ↔ pre-commit)"
VERSIONS_ENV="scripts/tool-versions.env"
PRECOMMIT_CFG=".pre-commit-config.yaml"
if [[ -r "$VERSIONS_ENV" && -r "$PRECOMMIT_CFG" ]]; then
  _ver() { sed -n "s/^$1=//p" "$VERSIONS_ENV" | head -n1; }
  # The rev: line immediately following a given repo: line in the pre-commit config.
  _pc_rev() { awk -v r="$1" '$0 ~ "repo:.*" r {f=1} f && $1=="rev:" {print $2; exit}' "$PRECOMMIT_CFG"; }
  _check_pin() { # _check_pin <repo-substr> <env-key> <label>
    local want got
    want="v$(_ver "$2")"
    got="$(_pc_rev "$1")"
    if [[ -n "$got" && "$got" == "$want" ]]; then
      pass "pre-commit $3 rev $got == tool-versions.env"
    else
      fail "pre-commit $3 rev '${got:-<none>}' != tool-versions.env '$want' — bump one to match"
    fi
  }
  _check_pin "koalaman/shellcheck-precommit" SHELLCHECK_VERSION shellcheck
  _check_pin "DavidAnson/markdownlint-cli2" MARKDOWNLINT_VERSION markdownlint
  _check_pin "pre-commit/pre-commit-hooks" PRECOMMIT_HOOKS_VERSION pre-commit-hooks
else
  skip "version consistency ($VERSIONS_ENV or $PRECOMMIT_CFG unreadable)"
fi

# ── 10. behavioral tests (load-order smoke + function unit tests) ─────────────
# Static analysis above proves the modules PARSE; this proves they LOAD TOGETHER
# in canonical order and that the pure functions behave. Delegated to test-core.sh
# (single source of truth) but folded into ONE audit summary via CORE_TEST_NESTED.
# Self-gates on zsh: with none installed it SKIPs, exactly like sections 3–5.
hdr "behavioral (scripts/test-core.sh)"
TEST_ARGS=(--scope "$(_scope_str)")
((QUIET)) && TEST_ARGS+=(--quiet)
# `${arr[@]+"${arr[@]}"}`, not `"${arr[@]}"`: under `set -u`, expanding an EMPTY array
# raises "unbound variable" on bash < 4.4 — i.e. macOS's stock bash 3.2, which this
# gate must run on. The `+` form expands to nothing when unset/empty and to the quoted
# elements otherwise, so the non-QUIET (empty TEST_ARGS) path stops aborting on macOS.
if CORE_TEST_NESTED=1 ./scripts/test-core.sh ${TEST_ARGS[@]+"${TEST_ARGS[@]}"}; then
  pass "behavioral tests (load-order smoke + function units)"
else
  fail "behavioral tests failed — run: ./scripts/test-core.sh"
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
