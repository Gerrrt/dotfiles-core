#!/usr/bin/env bash
# bin/bench-core.sh
# ──────────────────────────────────────────────────────────────────────────────
# Measure Core's contribution to interactive-shell startup time — the metric this
# repo invests in (cached starship/zoxide/mise/atuin init in tools.zsh, deferred
# heavy plugins in plugins.zsh) but never actually MEASURED, so a regression could
# ship silently to all 9 OS repos. This is the missing perf guard: run it before
# and after a change to the load path to see the delta.
#
# It benchmarks the SAME canonical load chain bin/test-core.sh asserts, in the
# SAME hermetic sandbox (throwaway HOME/ZDOTDIR, pre-seeded EMPTY plugin dirs so
# the first-run clone is a no-op) — so the number reflects Core's own load cost,
# reproducibly and with no network.
#
# Graceful degradation (mirrors audit-core.sh / test-core.sh): with no zsh OR no
# hyperfine it SKIPs and exits 0, so it is safe to call anywhere. hyperfine is the
# tool tools.zsh already detects as HAVE_HYPERFINE and the perf note in tools.zsh
# already points at (`hyperfine 'zsh -i -c exit'`).
#
# Usage:
#   ./bin/bench-core.sh            # benchmark the canonical Core load chain
#   CORE_BENCH_RUNS=20 ./bin/bench-core.sh   # override the min run count
# ──────────────────────────────────────────────────────────────────────────────
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$HERE" || exit 1

c_yel=$'\e[33m'
c_blu=$'\e[34m'
c_rst=$'\e[0m'
have() { command -v "$1" >/dev/null 2>&1; }
skip() { printf '%s–%s %s\n' "$c_yel" "$c_rst" "$*"; }

if ! have zsh; then
  skip "bench skipped (zsh not installed)"
  exit 0
fi
if ! have hyperfine; then
  skip "bench skipped (hyperfine not installed — tools.zsh detects it as HAVE_HYPERFINE)"
  exit 0
fi

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/core-bench.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT

# Pre-seed empty plugin dirs so plugins.zsh's first-run `git clone` is a no-op
# (hermetic, no network) — identical to bin/test-core.sh.
mkdir -p "$SANDBOX/zdot/plugins"
for plug in zsh-defer zsh-vi-mode zsh-history-substring-search \
  zsh-autosuggestions fast-syntax-highlighting fzf-tab zsh-you-should-use; do
  mkdir -p "$SANDBOX/zdot/plugins/$plug"
done

# The README/manifest canonical order (no os/local — those belong to OS repos).
CORE_MODULES=(tools options history aliases git functions fzf bindings plugins op maint update)
export CORE_DIR="$HERE/zsh"
# The `$CORE_DIR/$_m` here is expanded by the zsh CHILD reading this .zshrc, not by
# this bash parent — so SC2016 (un-expanded `$` in single quotes) is intended.
# shellcheck disable=SC2016
printf 'for _m in %s; do source "$CORE_DIR/$_m.zsh"; done\n' "${CORE_MODULES[*]}" \
  >"$SANDBOX/zdot/.zshrc"

runs="${CORE_BENCH_RUNS:-10}"
printf '\n%s== Core startup benchmark (canonical .zshrc chain, hermetic) ==%s\n' "$c_blu" "$c_rst"

# `zsh -i -c exit` sources the sandbox .zshrc (interactive, so the modules' `[[ $-
# == *i* ]]` guards pass) and exits. --warmup primes the fs/exec cache so the
# reported mean is steady-state, not first-run cold.
HOME="$SANDBOX" ZDOTDIR="$SANDBOX/zdot" \
  XDG_CACHE_HOME="$SANDBOX/cache" XDG_STATE_HOME="$SANDBOX/state" \
  XDG_RUNTIME_DIR="$SANDBOX/run" CORE_DIR="$CORE_DIR" \
  hyperfine --warmup 3 --min-runs "$runs" 'zsh -i -c exit'
