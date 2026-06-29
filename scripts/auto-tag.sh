#!/usr/bin/env bash
# scripts/auto-tag.sh — cut the next OS-repo release tag after a Core fan-out.
# ──────────────────────────────────────────────────────────────────────────────
# An OS repo carries TWO version lines: the Core it vendors (core.lock, bumped by
# sync-core.sh on every fan-out) and its OWN release tag (vX.Y.Z), which tracks that
# repo's history. The second line used to advance only by hand, so it drifted (most
# repos froze at an old tag; the newest had none). This closes that gap: when a fan-out
# lands a new Core on an OS repo's main, the repo's CI calls this to bump its own tag —
# PATCH by default (a new Core is a maintenance bump of the consumer), minor/major still
# deliberate. It runs in CI, where pushing a tag is allowed (no operator round-trip, and
# it sidesteps the env that can't push tags locally).
#
# Idempotent + safe by construction:
#   - a no-op if HEAD already carries a vX.Y.Z tag (re-runs, or a hand-cut release, never
#     double-tag);
#   - PRINTS the computed tag and exits unless --push is given (mirrors tag-release.sh /
#     sync-core.sh: the remote write is opt-in), so the version math is unit-testable
#     without a remote.
#
# Usage:
#   ./scripts/auto-tag.sh <repo-path>                 # print the next tag, touch nothing
#   ./scripts/auto-tag.sh <repo-path> --push          # …create the annotated tag and push it
#   ./scripts/auto-tag.sh <repo-path> --bump minor    # bump minor (default: patch)
#
# Flags:
#   --bump <patch|minor|major>   which component to advance       (default: patch)
#   --push                       create + push the tag to origin  (default: print only)
#   --initial <vX.Y.Z>           tag to use when the repo has NONE (default: v0.1.0)
#   --color <auto|always|never>  palette control
#   -h, --help                   show this help and exit
# ──────────────────────────────────────────────────────────────────────────────
set -uo pipefail

# shellcheck source=scripts/lib/common.sh
source "${BASH_SOURCE[0]%/*}/lib/common.sh"

usage() {
  cat <<'EOF'
usage: auto-tag.sh <repo-path> [--bump patch|minor|major] [--push]
                   [--initial vX.Y.Z] [--color auto|always|never]

Compute (and with --push, cut) the next vX.Y.Z release tag for an OS repo whose
vendored core/ just advanced. PATCH-bumps the repo's latest tag by default. A no-op
if HEAD is already tagged vX.Y.Z. Without --push it only prints the tag it would cut.

  --bump <patch|minor|major>   component to advance              (default: patch)
  --push                       create + push the tag to origin   (default: print only)
  --initial <vX.Y.Z>           tag when the repo has none         (default: v0.1.0)
  --color <auto|always|never>  palette control                    (default: auto)
  -h, --help                   show this help and exit
EOF
}

REPO=""
BUMP="patch"
PUSH=0
INITIAL=v0.1.0
while (($#)); do
  case "$1" in
  -h | --help)
    usage
    exit 0
    ;;
  --push) PUSH=1 ;;
  --bump)
    (($# >= 2)) || {
      fail "auto-tag.sh: --bump needs a value (patch|minor|major)"
      exit 2
    }
    BUMP="$2"
    shift
    ;;
  --initial)
    (($# >= 2)) || {
      fail "auto-tag.sh: --initial needs a vX.Y.Z value"
      exit 2
    }
    INITIAL="$2"
    shift
    ;;
  --color)
    (($# >= 2)) || {
      fail "auto-tag.sh: --color needs auto|always|never"
      exit 2
    }
    _core_set_color "$2" || {
      fail "auto-tag.sh: --color wants auto|always|never"
      exit 2
    }
    shift
    ;;
  -*)
    fail "auto-tag.sh: unknown option '$1'"
    usage >&2
    exit 2
    ;;
  *)
    [[ -z "$REPO" ]] || {
      fail "auto-tag.sh: unexpected extra argument '$1'"
      exit 2
    }
    REPO="$1"
    ;;
  esac
  shift
done

case "$BUMP" in patch | minor | major) ;; *)
  fail "auto-tag.sh: --bump wants patch|minor|major (got '$BUMP')"
  exit 2
  ;;
esac
[[ "$INITIAL" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  fail "auto-tag.sh: --initial must be vX.Y.Z (got '$INITIAL')"
  exit 2
}
[[ -n "$REPO" ]] || {
  fail "auto-tag.sh: need a repo path"
  usage >&2
  exit 2
}
have git || {
  fail "auto-tag.sh: git not found"
  exit 1
}
git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || {
  fail "auto-tag.sh: '$REPO' is not a git checkout"
  exit 1
}

# _next_version <X.Y.Z> <patch|minor|major> — pure SemVer bump, echoes the new X.Y.Z.
# Kept side-effect-free so the audit's behavioral suite can assert the math directly.
_next_version() {
  local cur="$1" level="$2" major minor patch
  IFS=. read -r major minor patch <<<"$cur"
  # Force base-10: a zero-padded component (e.g. 08) is read as octal by $(( )) and
  # `08`/`09` would error. Callers only pass strict X.Y.Z (digits), so 10# is safe.
  major=$((10#$major)) minor=$((10#$minor)) patch=$((10#$patch))
  case "$level" in
  major)
    major=$((major + 1))
    minor=0
    patch=0
    ;;
  minor)
    minor=$((minor + 1))
    patch=0
    ;;
  patch)
    patch=$((patch + 1))
    ;;
  esac
  printf '%s.%s.%s' "$major" "$minor" "$patch"
}

hdr "auto-tag $(basename "$REPO") (bump $BUMP)"

# _first_strict_semver — read tags on stdin (one per line) and echo the first that is a
# strict vX.Y.Z. git's `--list` takes a GLOB, not a regex, so a pattern like
# 'v[0-9]*.[0-9]*.[0-9]*' also matches pre-release/suffixed tags (v1.2.3-rc1) and a
# zero-pad — and would feed a non-numeric component into _next_version. It also can't
# exclude a moving major alias (v2). So we list ALL tags and filter here with an EXACT
# regex. A read loop (process substitution, not `| head`) sidesteps the pipefail/SIGPIPE
# race a pipe to head would introduce under `set -o pipefail`.
_first_strict_semver() {
  local t
  while IFS= read -r t; do
    [[ "$t" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] && {
      printf '%s' "$t"
      return 0
    }
  done
  return 0
}

# Guard 1 — idempotency: never double-tag a commit. If HEAD already carries a strict
# vX.Y.Z release, this run is a no-op (a re-trigger, or an operator who hand-cut it).
existing="$(_first_strict_semver < <(git -C "$REPO" tag --points-at HEAD))"
if [[ -n "$existing" ]]; then
  pass "HEAD already tagged $existing — nothing to do"
  exit 0
fi

# Latest existing release tag (highest strict SemVer), or the configured initial when
# the repo has never been tagged. --sort orders by version desc; the filter drops any
# non-vX.Y.Z (prerelease, suffix, or a vN major alias) so the FIRST kept line is the top.
latest="$(_first_strict_semver < <(git -C "$REPO" tag --sort=-v:refname))"
if [[ -z "$latest" ]]; then
  NEXT="$INITIAL"
  pass "no existing tag — seeding $NEXT"
else
  NEXT="v$(_next_version "${latest#v}" "$BUMP")"
  pass "latest $latest → $NEXT ($BUMP)"
fi

if ((!PUSH)); then
  printf '\n%s──────── would tag %s (dry-run; pass --push to cut it) ────────%s\n' "$c_blu" "$NEXT" "$c_rst"
  exit 0
fi

# Guard 2 — don't clobber a tag name that already exists somewhere in the repo.
if git -C "$REPO" rev-parse -q --verify "refs/tags/$NEXT" >/dev/null; then
  fail "auto-tag.sh: tag $NEXT already exists in $REPO — resolve before re-running"
  exit 1
fi

# Annotated tag (carries tagger/date; git describe expects it). A CI tagger identity so
# the object is well-formed when no user.* is configured in the runner.
git -C "$REPO" config user.name "${GIT_AUTHOR_NAME:-dotfiles-core auto-tag}"
git -C "$REPO" config user.email "${GIT_AUTHOR_EMAIL:-noreply@users.noreply.github.com}"
if git -C "$REPO" tag -a "$NEXT" -m "$NEXT"; then
  pass "tagged $NEXT"
else
  fail "auto-tag.sh: 'git tag -a $NEXT' failed"
  exit 1
fi
if git -C "$REPO" push origin "$NEXT"; then
  pass "pushed $NEXT → origin"
else
  fail "auto-tag.sh: push failed — re-push manually: git -C \"$REPO\" push origin \"$NEXT\""
  exit 1
fi
printf '\n%s──────── %s released ────────%s\n' "$c_blu" "$NEXT" "$c_rst"
