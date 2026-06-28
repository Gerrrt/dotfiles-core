#!/usr/bin/env bash
# scripts/tag-release.sh — finish a release: commit, annotated-tag, (optionally) push.
# ──────────────────────────────────────────────────────────────────────────────
# `release.sh` deliberately stops short of git: it bumps core.version, promotes the
# CHANGELOG, runs the audit, and PRINTS the commit/tag/push recipe for the operator to
# run by hand. That hand-run recipe is the last drift-prone step — a fat-fingered tag
# name or a forgotten `git push --tags` is exactly the class of mistake the rest of the
# release path is mechanized to avoid. This is the other half: it reads the version
# `release.sh` already stamped, re-proves the tree green, commits core.version+CHANGELOG,
# and creates the annotated `vX.Y.Z` tag — so `make release … && make tag` is the whole
# cut, end to end (RELEASE-STRATEGY.md gap 3).
#
# Push stays OPT-IN. Tagging is local and cheap to undo (`git tag -d`); pushing a tag to
# origin is the outward, hard-to-walk-back step, so it happens only with --push (or
# `make tag PUSH=1`). Without it, the script prints the exact push commands, mirroring
# release.sh's hands-off-the-remote stance.
#
# Usage:
#   ./scripts/tag-release.sh            # commit + annotated tag for core.version's value
#   ./scripts/tag-release.sh --push     # …then push the branch and the tag to origin
#   make tag                            # same, via the Makefile façade (PUSH=1 to push)
#
# Env:
#   TAG_SKIP_AUDIT=1   skip the green-tree gate (escape hatch for a tree you just audited)
# ──────────────────────────────────────────────────────────────────────────────
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$HERE" || exit 1

# shellcheck source=scripts/lib/common.sh
source "${BASH_SOURCE[0]%/*}/lib/common.sh"

usage() {
  cat <<'EOF'
usage: tag-release.sh [--push]

Finish the release that release.sh staged: commit core.version + CHANGELOG.md,
create the annotated tag vX.Y.Z (X.Y.Z = the current core.version), after proving
the tree green. Pushing is opt-in:

  --push        push the current branch and the new tag to origin
  -h, --help    show this help and exit

Env: TAG_SKIP_AUDIT=1 skips the audit gate (use only on a tree you just audited).
EOF
}

PUSH=0
case "${1:-}" in
-h | --help)
  usage
  exit 0
  ;;
--push)
  PUSH=1
  ;;
"") ;;
*)
  fail "tag-release.sh: unknown argument '$1'"
  usage >&2
  exit 2
  ;;
esac

have git || {
  fail "tag-release.sh: git not found"
  exit 1
}
git rev-parse --git-dir >/dev/null 2>&1 || {
  fail "tag-release.sh: not a git checkout"
  exit 1
}

CHANGELOG="CHANGELOG.md"
VERFILE="core.version"
[[ -r "$VERFILE" && -r "$CHANGELOG" ]] || {
  fail "tag-release.sh: $VERFILE or $CHANGELOG missing/unreadable"
  exit 1
}

VERSION="$(tr -d '[:space:]' <"$VERFILE")"
# A tag stamps a clean SemVer release — the same shape release.sh enforces. A
# prerelease/dirty core.version means no release was cut; refuse rather than tag junk.
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  fail "tag-release.sh: core.version ('$VERSION') is not a clean release (X.Y.Z) — run 'make release VERSION=X.Y.Z' first"
  exit 2
fi
TAG="v$VERSION"

hdr "tag $TAG (from core.version)"

# Guard 1: never clobber an existing tag — a re-run after a successful tag must be a
# clear no-op error, not a silent second tag or a moved ref.
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  fail "tag-release.sh: tag $TAG already exists — bump core.version or delete the tag to re-cut"
  exit 1
fi

# Guard 2: the CHANGELOG must already carry this version's dated heading — i.e.
# release.sh ran. Tagging a version with no changelog section is exactly the
# incoherence the audit's version/CHANGELOG gate exists to catch; refuse up front.
if ! grep -qE "^## +\[v?${VERSION//./\\.}\]" "$CHANGELOG"; then
  fail "tag-release.sh: no '## [v$VERSION]' heading in $CHANGELOG — run 'make release VERSION=$VERSION' first"
  exit 1
fi

# Guard 3: prove the tree green before it's tagged (the same gate release.sh and
# sync-core.sh enforce). Skippable for a tree you JUST audited, mirroring SYNC_SKIP_AUDIT.
if [[ "${TAG_SKIP_AUDIT:-0}" == 1 ]]; then
  skip "audit (TAG_SKIP_AUDIT=1)"
else
  hdr "audit (tag must be green)"
  if ./scripts/audit-core.sh --quiet; then
    pass "audit green"
  else
    fail "audit FAILED — fix before tagging (or TAG_SKIP_AUDIT=1 to override a just-audited tree)"
    exit 1
  fi
fi

# Commit the two release files iff they actually differ from HEAD (release.sh left them
# modified). Re-running after the commit already landed is a no-op, not an error. The
# explicit pathspec commits ONLY these two files, so unrelated staged work is never
# swept into the release commit.
if git diff --quiet HEAD -- "$VERFILE" "$CHANGELOG"; then
  pass "release commit already present ($VERFILE/$CHANGELOG match HEAD)"
else
  if git commit -q -m "release $TAG" -- "$VERFILE" "$CHANGELOG"; then
    pass "committed release $TAG"
  else
    fail "tag-release.sh: commit failed"
    exit 1
  fi
fi

# Annotated (not lightweight) tag: release.sh's printed recipe uses -a, git-cliff and
# `git describe` expect the annotation, and it carries the tagger/date.
if git tag -a "$TAG" -m "$TAG"; then
  pass "tagged $TAG"
else
  fail "tag-release.sh: 'git tag -a $TAG' failed"
  exit 1
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)"

if ((PUSH)); then
  hdr "push $BRANCH + $TAG → origin"
  if git push origin "$BRANCH" && git push origin "$TAG"; then
    pass "pushed $BRANCH and $TAG"
  else
    fail "tag-release.sh: push failed — the local commit+tag stand; re-push manually"
    exit 1
  fi
  printf '\n%s──────── %s released ────────%s\n' "$c_blu" "$TAG" "$c_rst"
  cat <<EOF
  fan out: ./scripts/sync-core.sh        # vendor $TAG into the OS repos
EOF
else
  printf '\n%s──────── %s tagged locally ────────%s\n' "$c_blu" "$TAG" "$c_rst"
  cat <<EOF
  review:  git show $TAG
  push:    git push origin $BRANCH && git push origin $TAG
           (or re-run: make tag PUSH=1)
  fan out: ./scripts/sync-core.sh        # vendor $TAG into the OS repos
EOF
fi
