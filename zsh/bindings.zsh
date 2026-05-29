# core/zsh/bindings.zsh
# Vi-mode keybindings. zsh-vi-mode resets all bindings on init, so we register
# them via its zvm_after_init hook. Load this BEFORE plugins.zsh (which sources
# zsh-vi-mode) so the hook is defined before vi-mode fires it. The widgets it
# references are defined in fzf.zsh / by atuin / by the plugins, all of which are
# loaded by the time the hook executes.

# Cursor shape per vi mode
ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BEAM
ZVM_NORMAL_MODE_CURSOR=$ZVM_CURSOR_BLOCK
ZVM_VISUAL_MODE_CURSOR=$ZVM_CURSOR_BLOCK

# Disable command mode line highlight
ZVM_VI_HIGHLIGHT_BACKGROUND=none
ZVM_VI_HIGHLIGHT_FOREGROUND=none
ZVM_VI_HIGHLIGHT_EXTRASTYLE=none

# zsh-vi-mode resets all bindings on init — register via hook to survive
zvm_after_init() {
  # --- Insert mode ---
  bindkey -M viins '^[[1;5C' forward-word          # Ctrl+Right
  bindkey -M viins '^[[1;5D' backward-word          # Ctrl+Left
  bindkey -M viins '^F'      _fzf_file_no_hidden    # Ctrl+F  → file picker
  bindkey -M viins '^R'      _fzf_history_clean     # Ctrl+R  → history
  # Ctrl+E → Atuin TUI. GUARDED: atuin registers _atuin_search_widget only when
  # it's installed (tools.zsh runs `atuin init zsh` earlier in load order). On a
  # bare box without atuin the widget doesn't exist, and binding it
  # unconditionally makes zsh warn "no such widget" on every shell start. Every
  # other widget here is always defined (fzf.zsh / the vendored plugins), so this
  # is the only line that needs the guard.
  (( $+widgets[_atuin_search_widget] )) && bindkey -M viins '^E' _atuin_search_widget
  bindkey -M viins '^\'      autosuggest-toggle     # Ctrl+\  → toggle suggestions
  bindkey -M viins '^[[A'    history-substring-search-up
  bindkey -M viins '^[[B'    history-substring-search-down
  bindkey -M viins '^[z'     _fzf_zoxide_jump       # Alt+Z   → zoxide jump
  bindkey -M viins '^G'      _tmux_sessionizer      # Ctrl+G  → project sessionizer

  # --- Normal / command mode ---
  bindkey -M vicmd '^[[1;5C' forward-word
  bindkey -M vicmd '^[[1;5D' backward-word
  bindkey -M vicmd '^[[A'    history-substring-search-up
  bindkey -M vicmd '^[[B'    history-substring-search-down
}
