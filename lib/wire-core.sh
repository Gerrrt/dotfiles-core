# shellcheck shell=bash
# core/lib/wire-core.sh — the ONE Core→destination symlink map, vendored into every OS repo.
# ──────────────────────────────────────────────────────────────────────────────
# Each OS repo's bootstrap.sh used to hand-roll the same ~40 lines that symlink the vendored
# core/ tree into ~/.config (zsh modules, tmux, nvim, starship, git, mise, …). That block was
# copy-pasted N ways and drifted: the per-repo copies disagreed on FORMAT and, worse, on
# CONTENT — core/lazygit/config.yml and core/vim/vimrc are in core.manifest yet NO bootstrap
# linked them, so two Core files shipped to every machine but reached none. This library is
# the single source of that map: a Core file added here links everywhere on the next sync,
# instead of needing a manual edit in each bootstrap (and being forgotten in some).
#
# Scope: this wires the OS-AGNOSTIC Core files only. The OS-native overlays (os/<os>.zsh ->
# zsh/os.zsh, os/<os>.conf -> tmux/os.conf, os/<os>.gitconfig -> git/os.gitconfig), the zsh
# entry layer, ssh, tpm, and provisioning stay in each bootstrap — they differ per OS. The
# bootstrap sources core/lib/ux.sh then this file, sets nothing, and calls:
#
#   wire_core_links "$DOTFILES" "${XDG_CONFIG_HOME:-$HOME/.config}"
#
# and may reuse the exported wire_link / wire_seed for its own OS-native links so the
# idempotent backup + dry-run behaviour is identical across the Core and OS layers.
#
# WIRE_DRY=1 prints the plan and changes nothing (the bootstrap's --dry-run/--links-only maps
# to it). SOURCED, not run: no shebang, mode 100644 (the audit asserts this for lib/*.sh, the
# bash sibling of the sourced zsh/*.zsh modules). bash 3.2-safe (macOS): no associative
# arrays, no mapfile, no ${x,,}.
# ──────────────────────────────────────────────────────────────────────────────
[[ -n "${_CORE_WIRE_SH:-}" ]] && return 0
_CORE_WIRE_SH=1

# Palette/glyphs come from the shared bash UX lib. It's the sibling of this file in core/lib,
# so a bootstrap that sourced this one can source that one too; if it didn't, pull it in here
# (idempotent — ux.sh self-guards). Fall back to bare ASCII if it's somehow unreadable so
# wire-core never hard-fails on a cosmetic dependency.
if [[ -z "${_CORE_UX_SH:-}" ]]; then
  _wire_self="${BASH_SOURCE[0]}"
  _wire_uxsh="$(cd "$(dirname "$_wire_self")" 2>/dev/null && pwd)/ux.sh"
  # shellcheck source=/dev/null
  [[ -r "$_wire_uxsh" ]] && source "$_wire_uxsh"
  unset _wire_self _wire_uxsh
fi
: "${UX_GRN:=}" "${UX_YEL:=}" "${UX_DIM:=}" "${UX_RST:=}"
: "${UX_OK:=ok}" "${UX_INFO:=-}" "${UX_WARN:=!}"

# Running tallies, reset at the top of wire_core_links so a second call (or an OS layer that
# reuses wire_link) starts clean. Read them after the call for a summary if desired.
WIRE_LINKED=0 WIRE_SEEDED=0 WIRE_BACKED=0 WIRE_SKIPPED=0

# wire_link <src> <dest> — symlink src->dest, backing up a real file once. Idempotent: an
# already-correct link is a no-op. A missing src is reported and skipped (so a Core file that
# hasn't synced yet doesn't abort the whole wiring). WIRE_DRY=1 prints the plan only.
wire_link() {
  local src="$1" dest="$2"
  if [[ ! -e "$src" ]]; then
    printf '  %s%s%s skip (missing): %s\n' "$UX_DIM" "$UX_INFO" "$UX_RST" "${src##*/}"
    WIRE_SKIPPED=$((WIRE_SKIPPED + 1))
    return 0
  fi
  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    printf '  %s%s%s %s (already linked)\n' "$UX_DIM" "$UX_OK" "$UX_RST" "${dest/#$HOME/~}"
    WIRE_LINKED=$((WIRE_LINKED + 1))
    return 0
  fi
  if [[ -n "${WIRE_DRY:-}" && "${WIRE_DRY}" != 0 ]]; then
    if [[ -L "$dest" ]]; then
      printf '  %s%s%s would relink: %s\n' "$UX_DIM" "$UX_INFO" "$UX_RST" "${dest/#$HOME/~}"
    elif [[ -e "$dest" ]]; then
      printf '  %s%s%s would back up, then link: %s\n' "$UX_DIM" "$UX_INFO" "$UX_RST" "${dest/#$HOME/~}"
      WIRE_BACKED=$((WIRE_BACKED + 1))
    else
      printf '  %s%s%s would link: %s\n' "$UX_DIM" "$UX_INFO" "$UX_RST" "${dest/#$HOME/~}"
    fi
    WIRE_LINKED=$((WIRE_LINKED + 1))
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  if [[ -L "$dest" ]]; then
    rm -f "$dest"
  elif [[ -e "$dest" ]]; then
    mv "$dest" "$dest.pre-dotfiles.$(date +%Y%m%d-%H%M%S)"
    printf '  %s%s%s backed up existing %s\n' "$UX_YEL" "$UX_WARN" "$UX_RST" "${dest/#$HOME/~}"
    WIRE_BACKED=$((WIRE_BACKED + 1))
  fi
  ln -s "$src" "$dest"
  printf '  %s%s%s %s\n' "$UX_GRN" "$UX_OK" "$UX_RST" "${dest/#$HOME/~}"
  WIRE_LINKED=$((WIRE_LINKED + 1))
}

# wire_seed <src> <dest> <note> — COPY (not symlink) a starter file when dest is absent, for
# files the user edits locally and that must not be tracked back (git identity, sesh layout).
# Present dest is left untouched. WIRE_DRY=1 prints the plan only.
wire_seed() {
  local src="$1" dest="$2" note="$3"
  if [[ ! -f "$src" || -e "$dest" ]]; then
    printf '  %s%s%s %s present (or no example) — left as-is\n' "$UX_DIM" "$UX_INFO" "$UX_RST" "${dest/#$HOME/~}"
    return 0
  fi
  if [[ -n "${WIRE_DRY:-}" && "${WIRE_DRY}" != 0 ]]; then
    printf '  %s%s%s would seed: %s (%s)\n' "$UX_DIM" "$UX_INFO" "$UX_RST" "${dest/#$HOME/~}" "$note"
    WIRE_SEEDED=$((WIRE_SEEDED + 1))
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  printf '  %s%s%s seeded %s — %s\n' "$UX_GRN" "$UX_OK" "$UX_RST" "${dest/#$HOME/~}" "$note"
  WIRE_SEEDED=$((WIRE_SEEDED + 1))
}

# wire_core_links <repo-root> <config-dir> — link every OS-agnostic Core file from
# <repo-root>/core/ to its canonical destination. This list IS the Core deployment map; keep
# it in step with core.manifest (a Core file with a user destination belongs here).
wire_core_links() {
  local repo="$1" cfg="${2:-$HOME/.config}"
  local core="$repo/core"
  WIRE_LINKED=0 WIRE_SEEDED=0 WIRE_BACKED=0 WIRE_SKIPPED=0

  if [[ ! -d "$core/zsh" ]]; then
    printf '  %s%s%s wire_core_links: %s/zsh not found — is the core/ subtree present?\n' \
      "$UX_YEL" "$UX_WARN" "$UX_RST" "$core" >&2
    return 1
  fi

  # cross-OS helper scripts onto PATH (called by zsh, tmux AND nvim)
  wire_link "$core/bin/clip" "$HOME/.local/bin/clip"
  wire_link "$core/bin/clip-paste" "$HOME/.local/bin/clip-paste"
  # Skip the exec-bit fix under WIRE_DRY — a dry run must change nothing, including the
  # mode of the vendored source files.
  [[ "${WIRE_DRY:-0}" != 0 ]] || chmod +x "$core/bin/clip" "$core/bin/clip-paste" 2>/dev/null || true

  # zsh modules — the whole load-order set (completions are fpath-added by options.zsh, not
  # symlinked; the OS layer adds os.zsh + the entry files itself)
  local f
  for f in "$core"/zsh/*.zsh; do
    [[ -e "$f" ]] && wire_link "$f" "$cfg/zsh/$(basename "$f")"
  done

  # prompt + lazygit theme (both at their tools' DEFAULT paths, so no env var needed)
  wire_link "$core/starship/starship.toml" "$cfg/starship.toml"
  wire_link "$core/lazygit/config.yml" "$cfg/lazygit/config.yml"

  # tmux base + keybinding layer + popup/status scripts
  wire_link "$core/tmux/tmux.conf" "$cfg/tmux/tmux.conf"
  wire_link "$core/tmux/tmux.reset.conf" "$cfg/tmux/tmux.reset.conf"
  if [[ -d "$core/tmux/scripts" ]]; then
    wire_link "$core/tmux/scripts" "$cfg/tmux/scripts"
    [[ "${WIRE_DRY:-0}" != 0 ]] || chmod +x "$core"/tmux/scripts/*.sh 2>/dev/null || true
  fi

  # neovim (whole lazy.nvim tree) + vim fallback for stock-vim-only boxes
  wire_link "$core/nvim" "$cfg/nvim"
  wire_link "$core/vim/vimrc" "$HOME/.vimrc"

  # mise global runtime versions
  wire_link "$core/mise/config.toml" "$cfg/mise/config.toml"

  # git portable config (identity/credential split to OS + a seeded, untracked local file)
  wire_link "$core/git/gitconfig" "$HOME/.gitconfig"
  wire_seed "$core/git/local.gitconfig.example" "$cfg/git/local.gitconfig" \
    "set your name/email there (never tracked)"

  # sesh portable session config (seeded; engagement layouts live in dotfiles-Kali)
  wire_seed "$core/sesh/sesh.toml.example" "$cfg/sesh/sesh.toml" \
    "edit freely; not tracked from here"
}
