#!/usr/bin/env bash
set -euo pipefail

# sync-upstream.sh — split the vendored Neovim config out of the current repo and
# push it upstream to dotfiles-core via `git subtree push`. Reached through the
# `gsync` alias (zsh/aliases.zsh resolves this file relative to itself, so the
# alias survives the core/ subtree vendoring — same trick maint.zsh uses).

# --- Configuration ------------------------------------------------------------
# The canonical upstream home of the Neovim config (the Core source of truth).
CORE_REPO_URL="https://github.com/Gerrrt/dotfiles-core"
# The target branch in the upstream repository.
TARGET_BRANCH="main"

# The Neovim folder location differs by where this script runs: in dotfiles-core
# the config sits at `nvim/`; once this file is vendored into an OS repo's core/
# subtree, it sits at `core/nvim/`. Resolve whichever exists from the repo root.
if [[ -d nvim ]]; then
    SUBTREE_PREFIX="nvim"
elif [[ -d core/nvim ]]; then
    SUBTREE_PREFIX="core/nvim"
else
    echo "❌ Error: could not locate the Neovim folder (looked for ./nvim and ./core/nvim)."
    echo "Run this from the repository root."
    exit 1
fi

echo "🔄 Initializing upstream synchronization sequence..."

# 1. Verify we are in a clean git working directory
if ! git diff-index --quiet HEAD --; then
    echo "❌ Error: Your working directory has uncommitted changes."
    echo "Please commit or stash your changes before syncing upstream."
    exit 1
fi

# 2. Report the current branch name (informational)
CURRENT_BRANCH="$(git branch --show-current)"
echo "📍 On branch '$CURRENT_BRANCH'."

echo "📡 Splitting and pushing changes from local '$SUBTREE_PREFIX' to core repository..."
echo "Target: $CORE_REPO_URL ($TARGET_BRANCH)"

# 3. Execute the git subtree push command
if git subtree push --prefix="$SUBTREE_PREFIX" "$CORE_REPO_URL" "$TARGET_BRANCH"; then
    echo "✅ Upstream synchronization complete! Core repository updated successfully."
else
    echo "❌ Git subtree split or push failed."
    echo "Tip: Verify your SSH keys or repository permissions, then try again."
    exit 1
fi
