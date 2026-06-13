#!/usr/bin/env bash
# bin/update-plugins.sh
# ──────────────────────────────────────────────────────────────────────────────
# Deliberately roll the pinned zsh-plugin revisions in zsh/plugins.zsh forward to
# each upstream's current default-branch HEAD. This is the runtime-plugin mirror of
# `make update-hooks` (pre-commit autoupdate) and the manual SHELLCHECK_VERSION /
# LUACHECK_VERSION bumps in ci.yml: pins exist so nothing floats silently into the
# 9 OS repos, and THIS is the one place they move — under review, not on their own.
#
# Single source of truth: the ZPLUGIN_PINS associative array in zsh/plugins.zsh.
# We parse the `owner/name  <40-hex sha>` rows straight out of it, `git ls-remote`
# each for HEAD, and rewrite only the SHA in place — so the plugin LIST never has
# to be repeated here and can never drift from what actually loads.
#
# Usage:
#   ./bin/update-plugins.sh            # bump every pin to upstream HEAD, in place
#   ./bin/update-plugins.sh --dry-run  # show what WOULD change, touch nothing
# ──────────────────────────────────────────────────────────────────────────────
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$HERE" || exit 1
PLUGINS_FILE="zsh/plugins.zsh"

DRY=0
[[ "${1:-}" == "--dry-run" || "${1:-}" == "-n" ]] && DRY=1

c_grn=$'\e[32m'
c_yel=$'\e[33m'
c_red=$'\e[31m'
c_blu=$'\e[34m'
c_rst=$'\e[0m'
have() { command -v "$1" >/dev/null 2>&1; }

have git || {
  printf '%s✗%s git not found — required to resolve upstream SHAs\n' "$c_red" "$c_rst" >&2
  exit 1
}
[[ -f "$PLUGINS_FILE" ]] || {
  printf '%s✗%s %s not found\n' "$c_red" "$c_rst" "$PLUGINS_FILE" >&2
  exit 1
}

# Pull the `owner/name  <sha>` rows out of ZPLUGIN_PINS. The grep matches a slug
# (owner/name) followed by a 40-hex commit — the exact shape of a pin row, so the
# array's comments and braces are ignored without needing to track block bounds.
mapfile -t ROWS < <(grep -oE '[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+[[:space:]]+[0-9a-f]{40}' "$PLUGINS_FILE")
[[ ${#ROWS[@]} -gt 0 ]] || {
  printf '%s✗%s no pinned plugins found in %s (is ZPLUGIN_PINS populated?)\n' "$c_red" "$c_rst" "$PLUGINS_FILE" >&2
  exit 1
}

printf '%s== rolling %d plugin pin(s) → upstream HEAD%s ==%s\n' \
  "$c_blu" "${#ROWS[@]}" "$([[ $DRY == 1 ]] && echo '  (dry-run)')" "$c_rst"

changed=0
fail=0
for row in "${ROWS[@]}"; do
  slug="${row%%[[:space:]]*}"          # owner/name
  old="${row##*[[:space:]]}"           # current 40-hex sha
  new="$(git ls-remote "https://github.com/${slug}" HEAD 2>/dev/null | awk 'NR==1{print $1}')"
  if [[ -z "$new" ]]; then
    printf '%s✗%s %-44s could not reach upstream\n' "$c_red" "$c_rst" "$slug" >&2
    fail=1
    continue
  fi
  if [[ "$new" == "$old" ]]; then
    printf '%s–%s %-44s up to date (%s)\n' "$c_yel" "$c_rst" "$slug" "${old:0:12}"
    continue
  fi
  printf '%s↑%s %-44s %s → %s\n' "$c_grn" "$c_rst" "$slug" "${old:0:12}" "${new:0:12}"
  changed=$((changed + 1))
  ((DRY)) && continue
  # Replace just this pin's SHA. Both old and new are 40-hex, so the literal old
  # SHA is unique in the file — a plain in-place substitution is unambiguous.
  tmp="$(mktemp "${PLUGINS_FILE}.XXXXXX")"
  sed "s/${old}/${new}/" "$PLUGINS_FILE" >"$tmp" && mv "$tmp" "$PLUGINS_FILE"
done

if ((fail)); then
  printf '%ssome upstreams were unreachable — pins left unchanged for those%s\n' "$c_red" "$c_rst" >&2
  exit 1
fi
if ((DRY)); then
  printf '%s%d pin(s) would change. Re-run without --dry-run to apply.%s\n' "$c_blu" "$changed" "$c_rst"
elif ((changed)); then
  printf '%s✓ %d pin(s) updated in %s — review the diff, run make audit, then commit.%s\n' \
    "$c_grn" "$changed" "$PLUGINS_FILE" "$c_rst"
else
  printf '%s✓ all pins already current.%s\n' "$c_grn" "$c_rst"
fi
