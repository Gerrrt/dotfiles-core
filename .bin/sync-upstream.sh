#!/usr/bin/env bash
set -euo pipefail

# sync-upstream.sh — push an OS repo's vendored `core/` subtree back upstream to
# dotfiles-core (the source of truth). Reached through the `gsync` alias
# (zsh/aliases.zsh resolves this file relative to itself, so the alias survives
# the core/ subtree vendoring — same trick maint.zsh uses).
#
# The subtree boundary is `core/` ⇄ dotfiles-core root@main: OS repos vendor ALL
# of Core under core/ via `git subtree add/pull --prefix=core <remote> main`
# (see scripts/sync-core.sh, scripts/new-os-repo.sh). So the only prefix that can
# round-trip back to dotfiles-core main is `core` — pushing a subdirectory like
# nvim/ would split a history with no common ancestor to main and be rejected.

# --- Configuration ------------------------------------------------------------
# The upstream source of truth that core/ is vendored from.
CORE_REPO_URL="https://github.com/Gerrrt/dotfiles-core"
# The target branch in the upstream repository.
TARGET_BRANCH="main"
# The vendored Core subtree, relative to the OS repo root.
SUBTREE_PREFIX="core"

echo "🔄 Initializing upstream synchronization sequence..."

# 1. This only makes sense from an OS repo that vendors core/. dotfiles-core IS
#    the upstream, so it has no core/ subtree and nothing to push upstream.
if [[ ! -d "$SUBTREE_PREFIX" ]]; then
    echo "❌ Error: no '$SUBTREE_PREFIX/' subtree found here."
    echo "Run gsync from the root of an OS repo (dotfiles-Fedora, dotfiles-Arch, …)"
    echo "whose $SUBTREE_PREFIX/ is vendored from dotfiles-core. dotfiles-core itself"
    echo "is the source of truth — there is nothing to push upstream from it."
    exit 1
fi

# 2. Verify we are in a clean git working directory
if ! git diff-index --quiet HEAD --; then
    echo "❌ Error: Your working directory has uncommitted changes."
    echo "Please commit or stash your changes before syncing upstream."
    exit 1
fi

# 3. Report the current branch name (informational)
CURRENT_BRANCH="$(git branch --show-current)"
echo "📍 On branch '$CURRENT_BRANCH'."

echo "📡 Splitting and pushing changes from local '$SUBTREE_PREFIX' to core repository..."
echo "Target: $CORE_REPO_URL ($TARGET_BRANCH)"

# 4. Execute the git subtree push command
if git subtree push --prefix="$SUBTREE_PREFIX" "$CORE_REPO_URL" "$TARGET_BRANCH"; then
    echo "✅ Upstream synchronization complete! Core repository updated successfully."
else
    echo "❌ Git subtree split or push failed."
    echo "Tip: a rejected non-fast-forward usually means dotfiles-core 'main' moved —"
    echo "pull Core back down first (make sync / git subtree pull), then retry."
    echo "Otherwise verify your SSH keys or repository permissions."
    exit 1
fi
