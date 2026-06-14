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
#   REPOS_ROOT   parent dir holding the repos   (default: parent of this repo)
#   CORE_REMOTE  remote name/URL for dotfiles-core in each OS repo (default: origin of core)
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

echo ":: core remote = $CORE_REMOTE  (branch $CORE_BRANCH @ $CORE_SHA)"
echo ":: repos root  = $REPOS_ROOT"
echo

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

echo "done. push each updated repo when you're satisfied."
