# core/zsh/options.zsh
# ──────────────────────────────────────────────────────────────────────────────
# Portable zsh options + the completion system. NEW in the 2026 refresh: this
# centralizes setopts and `compinit` that previously had to live in each OS repo's
# .zshrc loader (i.e. up to eight copies of the same portable config — exactly the
# drift this whole Core layer exists to kill).
#
# LOAD ORDER: source this SECOND, right after tools.zsh. compinit must run here so
# it's done before fzf-tab and carapace (both in plugins.zsh) and before any
# `compdef` calls (e.g. the eza completion reuse in aliases.zsh).
#
# Idempotent: if your OS .zshrc still calls compinit itself, REMOVE it there —
# the sentinel below makes a double-source here a no-op, but it can't stop a
# separate caller.
# ──────────────────────────────────────────────────────────────────────────────

[[ $- == *i* ]] || return 0

# ── setopt: navigation ────────────────────────────────────────────────────────
setopt AUTO_CD    # `dotfiles-core` == `cd dotfiles-core`
setopt AUTO_PUSHD # cd pushes onto the dir stack
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT
setopt CDABLE_VARS

# ── setopt: globbing / misc ───────────────────────────────────────────────────
setopt EXTENDED_GLOB        # #, ~, ^ in globs (and the (#qN) qualifiers below)
setopt GLOB_DOTS            # globs match dotfiles (handy in a dotfiles repo)
setopt NO_NOMATCH           # don't error when a glob matches nothing
setopt INTERACTIVE_COMMENTS # allow # comments at the interactive prompt
setopt NO_BEEP
setopt NO_CLOBBER # `>` won't overwrite; use `>|` to force
setopt NUMERIC_GLOB_SORT

# ── setopt: completion behaviour ──────────────────────────────────────────────
setopt COMPLETE_IN_WORD # complete from both ends of the word
setopt ALWAYS_TO_END
setopt PATH_DIRS
setopt AUTO_MENU
setopt NO_MENU_COMPLETE # show the menu, don't auto-insert the first match
unsetopt FLOW_CONTROL   # free up Ctrl-S / Ctrl-Q

# ── Completion system (cached: rebuild .zcompdump at most once per 24h) ────────
typeset -g _CORE_COMPINIT_DONE
if [[ -z $_CORE_COMPINIT_DONE ]]; then
  _CORE_COMPINIT_DONE=1
  autoload -Uz compinit
  local zcd="${ZDOTDIR:-$HOME/.config/zsh}/.zcompdump"
  # (#qN.mh+24): exists, is a file, modified >24h ago → do the full security check
  if [[ -n ${zcd}(#qN.mh+24) ]]; then
    compinit -d "$zcd"
  else
    compinit -C -d "$zcd" # fresh enough → skip the check (fast path)
  fi
  # compile the dump for a faster next start
  [[ -s "$zcd" && (! -s "${zcd}.zwc" || "$zcd" -nt "${zcd}.zwc") ]] && zcompile "$zcd"
fi

# ── Completion styling (zstyle) — portable, theme-neutral ─────────────────────
zstyle ':completion:*' completer _extensions _complete _approximate
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{blue}── %d ──%f'
zstyle ':completion:*:warnings' format '%F{red}no matches%f'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*' rehash true
