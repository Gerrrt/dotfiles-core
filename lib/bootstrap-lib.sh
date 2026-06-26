# shellcheck shell=bash
# core/lib/bootstrap-lib.sh — shared BASH provisioning scaffold for OS bootstraps.
# ──────────────────────────────────────────────────────────────────────────────
# ONE definition of the symlink/loader/login-shell scaffold that every OS repo's
# bootstrap.sh used to hand-roll. Before this, ~half of each of the seven Linux/Kali
# bootstrap.sh files was the SAME code — link(), read_pkgs(), WSL detection, the big
# Core-symlink loop, the .zshrc loader heredoc, the default-shell logic — copy-pasted
# and then independently reformatted (tabs vs spaces), so a fix to any of it had to be
# made seven times by hand. That is exactly the N-way drift the Core layer exists to
# kill, leaking back through the one file that can't be vendored. This is the fix:
# the shared half lives here, vendored under core/lib/, and each bootstrap.sh shrinks
# to its genuinely OS-specific part (the package install) plus calls into these helpers.
#
# zsh/ui.zsh is the zsh-runtime UX lib; lib/ux.sh is its bash sibling; this is the bash
# PROVISIONING sibling. Like ux.sh it IS vendored into every OS repo (it's in
# core.manifest) precisely so bootstrap.sh — which runs before any zsh config — can
# `source core/lib/bootstrap-lib.sh` instead of duplicating it.
#
# SOURCED, not run: no shebang, mode 100644 (the audit's exec-bit section asserts this
# for lib/*.sh, the bash sibling of the sourced zsh/*.zsh modules). bash 3.2-safe (macOS):
# no associative arrays, no mapfile, no ${x,,}.
#
# CHICKEN-AND-EGG: the core/ subtree presence check CANNOT move here — you can't source
# a lib out of core/ before confirming core/ exists. Each bootstrap.sh keeps that one
# guard inline (three lines), then sources lib/ux.sh + this file and calls in.
#
# Messaging uses lib/ux.sh's UX_* palette when it has been sourced first (the intended
# order), and degrades to plain/no-colour when it hasn't — so this file has no hard
# ordering dependency on ux.sh.
#
# Usage (in an OS bootstrap.sh):
#   source "$DOTFILES/core/lib/ux.sh"
#   source "$DOTFILES/core/lib/bootstrap-lib.sh"
#   blib_is_wsl && IS_WSL=1
#   wire_links() {
#     blib_link_core      "$DOTFILES" "$CONFIG"
#     blib_link_os_layer  "$DOTFILES" "$CONFIG" fedora
#     blib_write_zshrc_loader        # default module set; Kali passes its own (see below)
#     blib_set_login_shell
#   }
# ──────────────────────────────────────────────────────────────────────────────

[[ -n "${_CORE_BOOTSTRAP_LIB_SH:-}" ]] && return 0
_CORE_BOOTSTRAP_LIB_SH=1

# ── messages ──────────────────────────────────────────────────────────────────
# Thin wrappers over the UX_* palette (set by lib/ux.sh). When ux.sh wasn't sourced,
# UX_* expand empty and these stay plain — no hard dependency, no colour codes leak.
blib_say()  { printf '%s::%s %s\n'   "${UX_BLU:-}"  "${UX_RST:-}" "$*"; }
blib_ok()   { printf '%s%s%s %s\n'   "${UX_GRN:-}"  "${UX_OK:-+}"   "${UX_RST:-}" "$*"; }
blib_warn() { printf '%s%s%s %s\n'   "${UX_YEL:-}"  "${UX_WARN:-!}" "${UX_RST:-}" "$*" >&2; }

# ── WSL detection ─────────────────────────────────────────────────────────────
# Returns 0 on WSL (so callers do `blib_is_wsl && IS_WSL=1`). The same probe every
# bootstrap used: the WSL_DISTRO_NAME env first, then the microsoft/wsl marker in
# /proc/version (covers a login that didn't inherit the env).
blib_is_wsl() {
  [[ -n "${WSL_DISTRO_NAME:-}" ]] && return 0
  grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null
}

# ── symlink with backup ───────────────────────────────────────────────────────
# blib_link <src> <dst> — replace an existing SYMLINK in place; back up a real file
# to <dst>.pre-dotfiles.<epoch> first. Idempotent (safe to re-run a bootstrap).
blib_link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" ]]; then
    rm -f "$dst"
  elif [[ -e "$dst" ]]; then
    mv "$dst" "$dst.pre-dotfiles.$(date +%s)"
  fi
  ln -s "$src" "$dst"
}

# ── read a package list ───────────────────────────────────────────────────────
# blib_read_pkgs <file> — print one clean package name per line, stripping inline
# (#...) comments and all whitespace (package names contain none). Callers feed this
# into their own `mapfile -t pkgs < <(blib_read_pkgs …)` and hand pkgs to apt/dnf/apk.
blib_read_pkgs() {
  local line
  while IFS= read -r line; do
    line="${line%%#*}"           # drop everything from the first # onward
    line="${line//[[:space:]]/}" # package names contain no whitespace
    [[ -n "$line" ]] && printf '%s\n' "$line"
  done <"$1"
}

# ── symlink the vendored Core surface ─────────────────────────────────────────
# blib_link_core <dotfiles> <config> — link everything Core ships, identically on
# every OS: the zsh modules, tmux base + reset + popup scripts, starship, nvim, mise,
# git config (+ a once-seeded local identity), the cross-OS bin/clip* helpers, the
# ssh client config, and a one-time tpm clone. OS-specific overlays (os/<os>.*) are
# NOT here — call blib_link_os_layer for those.
blib_link_core() {
  local dotfiles="$1" config="$2" f s

  blib_say "symlinking Core"
  for f in "$dotfiles"/core/zsh/*.zsh; do
    blib_link "$f" "$config/zsh/$(basename "$f")"
  done

  [[ -f "$dotfiles/core/tmux/tmux.conf" ]] && blib_link "$dotfiles/core/tmux/tmux.conf" "$config/tmux/tmux.conf"
  [[ -f "$dotfiles/core/tmux/tmux.reset.conf" ]] && blib_link "$dotfiles/core/tmux/tmux.reset.conf" "$config/tmux/tmux.reset.conf"
  # tmux popup scripts (prefix w/T/f) — symlink the dir + ensure they're runnable.
  if [[ -d "$dotfiles/core/tmux/scripts" ]]; then
    blib_link "$dotfiles/core/tmux/scripts" "$config/tmux/scripts"
    chmod +x "$dotfiles"/core/tmux/scripts/*.sh 2>/dev/null || true
  fi
  # tmux plugin manager (tpm) — clone once so the theme + resurrect/continuum load.
  # Plugins still need one install pass: `prefix + I` in tmux.
  if [[ ! -d "$config/tmux/plugins/tpm" ]]; then
    blib_say "cloning tpm (tmux plugin manager)"
    if git clone --depth=1 https://github.com/tmux-plugins/tpm "$config/tmux/plugins/tpm" >/dev/null 2>&1; then
      blib_ok "tpm cloned — run prefix + I in tmux to install plugins"
    else
      blib_say "tpm clone failed — clone it manually, then prefix + I"
    fi
  fi

  # starship prompt theme — symlink to the DEFAULT path (tools.zsh inits starship
  # against ~/.config/starship.toml with no STARSHIP_CONFIG).
  [[ -f "$dotfiles/core/starship/starship.toml" ]] && blib_link "$dotfiles/core/starship/starship.toml" "$config/starship.toml"
  [[ -d "$dotfiles/core/nvim" ]] && blib_link "$dotfiles/core/nvim" "$config/nvim"
  [[ -f "$dotfiles/core/mise/config.toml" ]] && blib_link "$dotfiles/core/mise/config.toml" "$config/mise/config.toml"
  [[ -f "$dotfiles/core/git/gitconfig" ]] && blib_link "$dotfiles/core/git/gitconfig" "$HOME/.gitconfig"

  # private identity file, seeded ONCE from the example (never tracked, never relinked).
  if [[ ! -f "$config/git/local.gitconfig" && -f "$dotfiles/core/git/local.gitconfig.example" ]]; then
    mkdir -p "$config/git"
    cp "$dotfiles/core/git/local.gitconfig.example" "$config/git/local.gitconfig"
    blib_say "seeded ~/.config/git/local.gitconfig — FILL IN your name & email"
  fi

  # cross-OS helper scripts from Core onto PATH (~/.local/bin).
  if [[ -d "$dotfiles/core/bin" ]]; then
    mkdir -p "$HOME/.local/bin"
    for s in clip clip-paste; do
      if [[ -f "$dotfiles/core/bin/$s" ]]; then
        blib_link "$dotfiles/core/bin/$s" "$HOME/.local/bin/$s"
        chmod +x "$dotfiles/core/bin/$s" 2>/dev/null || true
      fi
    done
  fi

  # ssh client config (keys are NEVER tracked — only ssh/config). ssh is strict about
  # permissions: ~/.ssh must be 0700, and ControlMaster needs the sockets dir to exist.
  if [[ -f "$dotfiles/ssh/config" ]]; then
    blib_say "symlinking ssh/config"
    mkdir -p "$HOME/.ssh/sockets"
    chmod 700 "$HOME/.ssh" "$HOME/.ssh/sockets"
    chmod 600 "$dotfiles/ssh/config" 2>/dev/null || true
    blib_link "$dotfiles/ssh/config" "$HOME/.ssh/config"
    blib_ok "ssh/config linked into ~/.ssh (generate a key with: ssh-keygen -t ed25519)"
  fi
}

# ── symlink the OS-native overlays ────────────────────────────────────────────
# blib_link_os_layer <dotfiles> <config> <os> — link the three OS overlay files when
# present: os/<os>.conf → tmux/os.conf, os/<os>.zsh → zsh/os.zsh (the loader's `os`
# stage), os/<os>.gitconfig → git/os.gitconfig (included by Core's gitconfig).
blib_link_os_layer() {
  local dotfiles="$1" config="$2" os="$3"
  [[ -f "$dotfiles/os/$os.conf" ]] && blib_link "$dotfiles/os/$os.conf" "$config/tmux/os.conf"
  [[ -f "$dotfiles/os/$os.gitconfig" ]] && blib_link "$dotfiles/os/$os.gitconfig" "$config/git/os.gitconfig"
  if [[ -f "$dotfiles/os/$os.zsh" ]]; then
    blib_say "symlinking $os OS-native layer"
    blib_link "$dotfiles/os/$os.zsh" "$config/zsh/os.zsh"
  fi
}

# ── write the .zshrc entry loader ─────────────────────────────────────────────
# blib_write_zshrc_loader [module...] — write the managed ~/.zshrc that sets the env
# the Core modules expect and sources the vendored Core loader in the ONE canonical
# order. Pass a custom module list to add a role stage (Kali passes its `offensive`
# stage just before `local`); with no args it writes the standard set. Idempotent:
# a no-op if a "dotfiles-managed v2" loader is already in place; backs up any prior
# hand-rolled ~/.zshrc first. The heredocs are single-quoted, so $HOME/$ZDOTDIR/etc.
# stay LITERAL in the written file (evaluated at shell start, not at write time).
blib_write_zshrc_loader() {
  local rc="$HOME/.zshrc"
  local modules="$*"
  [[ -n "$modules" ]] || modules="tools ui options history aliases git functions fzf bindings plugins op maint update os local"

  if [[ -f "$rc" ]] && grep -q "dotfiles-managed v2" "$rc" 2>/dev/null; then
    return 0
  fi
  blib_say "writing .zshrc loader"
  [[ -f "$rc" ]] && cp "$rc" "$rc.pre-dotfiles.$(date +%s)"

  {
    cat <<'ZRC_HEAD'
# dotfiles-managed v2 — do not hand-edit; local tweaks go in ~/.config/zsh/local.zsh
# This entry file sets the env the Core modules expect (no ~/.zshenv is assumed), then
# sources the vendored Core loader in the ONE correct order.

# ── XDG + env ─────────────────────────────────────────────────────────────────
: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_STATE_HOME:=$HOME/.local/state}"
: "${XDG_CACHE_HOME:=$HOME/.cache}"
export EDITOR=nvim VISUAL=nvim
export NOTES_DIR="${NOTES_DIR:-$HOME/Notes}"

# ── Core modules (+ any role stage) + os + local, in canonical order ──────────
# options.zsh owns the nav/glob setopts + compinit + completion zstyles; history.zsh
# owns HISTFILE/HISTSIZE. This file just declares the load order and sources the
# vendored Core loader (core/zsh/loader.zsh -> $ZSH_CFG/loader.zsh), which
# byte-compiles + sources each module.
: "${ZDOTDIR:=$XDG_CONFIG_HOME/zsh}"
export ZDOTDIR              # Core modules (history/options) key state off ZDOTDIR;
ZSH_CFG="$ZDOTDIR"          # align the loader to the SAME dir so state never splits
ZRC_HEAD

    printf '_CORE_MODULES=(%s)\n' "$modules"

    cat <<'ZRC_TAIL'
if [[ -r "$ZSH_CFG/loader.zsh" ]]; then
  source "$ZSH_CFG/loader.zsh"
else
  print -u2 -- "zshrc: Core loader not found at $ZSH_CFG/loader.zsh — re-run the dotfiles bootstrap to (re)link Core."
fi
unset _CORE_MODULES
ZRC_TAIL
  } >"$rc"
}

# ── privilege escalation ──────────────────────────────────────────────────────
# _blib_priv <cmd...> — run CMD under $BLIB_SU (default `sudo`), or directly when
# it's empty (already root). Keeps the escalator a single token and never invokes an
# empty-string command — so a doas-only box (BLIB_SU=doas) or a root box (BLIB_SU="")
# both work. A caller on Alpine sets BLIB_SU="$SU" before calling the helpers below.
_blib_priv() {
  local su="${BLIB_SU-sudo}"
  if [[ -n "$su" ]]; then "$su" "$@"; else "$@"; fi
}

# ── make zsh the default login shell ──────────────────────────────────────────
# blib_set_login_shell — set zsh as the user's LOGIN shell (a fresh WSL/login session
# starts the login shell, not `exec zsh`). Idempotent: acts only if it isn't already
# zsh. Reads the current shell via getent when present, else straight from /etc/passwd
# (busybox/Alpine has no getent).
blib_set_login_shell() {
  command -v zsh >/dev/null || return 0
  local zsh_path user current
  zsh_path="$(command -v zsh)"
  user="$(id -un)"
  if command -v getent >/dev/null 2>&1; then
    current="$(getent passwd "$user" | cut -d: -f7)"
  else
    current="$(grep "^$user:" /etc/passwd | cut -d: -f7)"
  fi
  [[ "$current" == "$zsh_path" ]] && return 0

  blib_say "setting zsh as default login shell"
  grep -qxF "$zsh_path" /etc/shells || echo "$zsh_path" | _blib_priv tee -a /etc/shells >/dev/null
  if command -v chsh >/dev/null 2>&1; then
    _blib_priv chsh -s "$zsh_path" "$user" && blib_ok "default shell -> zsh (applies to NEW logins)"
  else
    blib_say "chsh not found (install the 'shadow' package) — set it manually with usermod -s $zsh_path $user"
  fi
}
