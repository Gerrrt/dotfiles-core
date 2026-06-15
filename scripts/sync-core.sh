#!/usr/bin/env bash
# scripts/sync-core.sh
# ──────────────────────────────────────────────────────────────────────────────
# THE MAINTAIN BUTTON.
#
# After you change Core (here, in dotfiles-core) and push, run this to pull the
# update into every OS repo's vendored core/ subtree. Replaces the old N-way
# manual reconciliation with one mechanical loop.
#
# Assumes:
#   - all OS repos are cloned as siblings under one parent dir (see REPOS_ROOT)
#   - each OS repo already did the one-time:
#       git subtree add --prefix=core <core-remote> main --squash
#
# Usage:
#   ./scripts/sync-core.sh                # pull core into every repo found
#   ./scripts/sync-core.sh --dry-run      # show what would happen, touch nothing
#   ./scripts/sync-core.sh dotfiles-Fedora dotfiles-Arch   # only these
#
# Env overrides:
#   REPOS_ROOT        parent dir holding the repos   (default: parent of this repo)
#   CORE_REMOTE       remote name/URL for dotfiles-core in each OS repo (default: origin of core)
#   SYNC_SKIP_AUDIT   set to 1 to skip the pre-fan-out audit gate (escape hatch; see below)
#
# FAN-OUT GATE: this is the single point where Core is vendored into all 9 repos, so a
# defect here amplifies N-way — exactly what audit-core.sh exists to prevent. The repo's
# thesis is "gate BEFORE vendoring", but nothing mechanically enforced that AT the step
# that vendors: it relied on the operator remembering `make audit`. So this script now
# runs the audit itself and REFUSES to fan out a red tree (--dry-run is exempt — it
# touches nothing; SYNC_SKIP_AUDIT=1 is the documented escape hatch for a tree you just
# audited). It also warns when local HEAD differs from the remote tip that actually fans
# out, so you never sync a commit you didn't audit locally.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPOS_ROOT="${REPOS_ROOT:-$(dirname "$HERE")}"
CORE_BRANCH="${CORE_BRANCH:-main}"

# Default: read the core repo's own origin URL so each OS repo pulls from the
# same place. Override with CORE_REMOTE if your OS repos use a named remote.
CORE_REMOTE="${CORE_REMOTE:-$(git -C "$HERE" remote get-url origin 2>/dev/null || echo '')}"

ALL_OS_REPOS=(
  dotfiles-MacBook dotfiles-Windows dotfiles-Debian dotfiles-Kali
  dotfiles-Fedora dotfiles-Arch dotfiles-openSUSE
  dotfiles-Alpine dotfiles-Gentoo
)

DRY=0
SELECT=()
for arg in "$@"; do
  case "$arg" in
  --dry-run | -n) DRY=1 ;;
  -h | --help)
    sed -n '2,30p' "$0"
    exit 0
    ;;
  dotfiles-*) SELECT+=("$arg") ;;
  *)
    echo "unknown arg: $arg" >&2
    exit 1
    ;;
  esac
done
[[ ${#SELECT[@]} -gt 0 ]] && TARGETS=("${SELECT[@]}") || TARGETS=("${ALL_OS_REPOS[@]}")

# Shared palette + pass/skip/fail/have (one definition for every gate script).
# This script doesn't tally, so the counters the lib keeps go unread; `ok`/`err`
# are kept as thin aliases for pass/fail so the call sites below read naturally.
# shellcheck source=scripts/lib/common.sh
source "${BASH_SOURCE[0]%/*}/lib/common.sh"
ok() { pass "$@"; }
err() { fail "$@"; }

[[ -n "$CORE_REMOTE" ]] || {
  err "CORE_REMOTE empty (set origin on dotfiles-core, or export CORE_REMOTE)"
  exit 1
}

# The exact dotfiles-core revision each OS repo will receive — surfaced so a sync
# is traceable (which Core commit landed where; pairs with CHANGELOG.md). ls-remote
# is the source of truth: it's the tip `subtree pull` fetches, even if the local
# checkout is behind. Falls back to the local branch SHA when offline. (The empty
# assignment from a failed $() does NOT trip `set -e`, so the fallback runs.)
CORE_SHA="$(git ls-remote "$CORE_REMOTE" "$CORE_BRANCH" 2>/dev/null | awk 'NR==1{print substr($1,1,12)}')"
[[ -n "$CORE_SHA" ]] || CORE_SHA="$(git -C "$HERE" rev-parse --short=12 "$CORE_BRANCH" 2>/dev/null || echo unknown)"

# Human-readable version stamp (core.version) — vendored into each OS repo so its
# `core-version` verb can report which Core it carries. Surfaced here too so the
# fan-out log records BOTH the SemVer and the commit that landed.
CORE_VERSION="$(tr -d '[:space:]' <"$HERE/core.version" 2>/dev/null || echo unknown)"
[[ -n "$CORE_VERSION" ]] || CORE_VERSION=unknown

echo ":: core version = $CORE_VERSION"
echo ":: core remote  = $CORE_REMOTE  (branch $CORE_BRANCH @ $CORE_SHA)"
echo ":: repos root   = $REPOS_ROOT"
echo

# ── Pre-fan-out gate: Core must be audit-green, and what you audited must be what
# fans out. Skipped for --dry-run (nothing is written) and via SYNC_SKIP_AUDIT=1. ──
if ((!DRY)) && [[ "${SYNC_SKIP_AUDIT:-0}" != 1 ]]; then
  # 1. The code must pass its own gate before it lands in 9 repos. We run the same
  #    audit CI and pre-commit run — one definition of "Core is healthy".
  echo ":: pre-fan-out audit (scripts/audit-core.sh --quiet)"
  if ! "$HERE/scripts/audit-core.sh" --quiet; then
    err "Core audit FAILED — refusing to fan out a red tree to $((${#TARGETS[@]})) repos"
    fail "fix the audit (or, if you must, re-run with SYNC_SKIP_AUDIT=1)"
    exit 1
  fi
  ok "Core audit green — safe to fan out"
  # 2. subtree pull fetches the REMOTE tip, not this working tree — so warn if local
  #    HEAD differs from the $CORE_SHA that will actually be vendored. (Best-effort:
  #    only when origin is resolvable; a detached/odd checkout just skips the check.)
  local_head="$(git -C "$HERE" rev-parse --short=12 HEAD 2>/dev/null || echo '')"
  if [[ -n "$local_head" && "$CORE_SHA" != unknown && "$local_head" != "$CORE_SHA" ]]; then
    err "local HEAD ($local_head) != remote tip being fanned out ($CORE_SHA)"
    fail "the audit above validated your LOCAL tree, not what will vendor — push/pull to align, or set SYNC_SKIP_AUDIT=1"
    exit 1
  fi
  echo
fi

for repo in "${TARGETS[@]}"; do
  path="$REPOS_ROOT/$repo"
  if [[ ! -d "$path/.git" ]]; then
    skip "$repo (not cloned at $path)"
    continue
  fi
  if [[ ! -d "$path/core" ]]; then
    skip "$repo (no core/ subtree yet — run the one-time 'git subtree add' first)"
    continue
  fi
  if ((DRY)); then
    echo "would: git -C $path subtree pull --prefix=core $CORE_REMOTE $CORE_BRANCH --squash   (→ $CORE_SHA)"
    continue
  fi
  # bail if the OS repo has a dirty tree — subtree merges into a clean state only
  if [[ -n "$(git -C "$path" status --porcelain)" ]]; then
    err "$repo has uncommitted changes — commit/stash first, skipping"
    continue
  fi
  echo ":: $repo"
  if git -C "$path" subtree pull --prefix=core "$CORE_REMOTE" "$CORE_BRANCH" --squash; then
    ok "$repo core/ updated → $CORE_SHA"
  else
    err "$repo subtree pull failed — resolve, then re-run"
  fi
  echo
done

# Scannable tally of the fan-out — sync sources common.sh (which counts every
# ok/skip/err via PASS/SKIP/FAIL) but used to end on a bare "done", forcing you to
# scroll a 9-repo run to learn what actually landed. Print the same summary footer the
# audit/test gates use so the single highest-stakes operation reports at a glance.
printf '\n%s──────── sync summary ────────%s\n' "$c_blu" "$c_rst"
printf '  %supdated %d%s   %sskipped %d%s   %sfailed %d%s\n' \
  "$c_grn" "$PASS" "$c_rst" "$c_yel" "$SKIP" "$c_rst" "$c_red" "$FAIL" "$c_rst"
if ((DRY)); then
  echo "dry-run — nothing was written."
elif ((FAIL > 0)); then
  echo "done with failures — see the ✗ lines above, then re-run the affected repos." >&2
else
  echo "done. push each updated repo when you're satisfied."
fi
