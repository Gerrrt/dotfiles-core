# core/zsh/fzf.zsh
# fzf config + custom zle widgets. Promoted from the Mac; portable across boxes
# (needs fzf + fd + bat + eza; all in the Core stack). The zle widgets defined
# here are bound to keys in bindings.zsh, so load this BEFORE bindings/plugins.

# =========================================================
# fzf core
# =========================================================
export FZF_DEFAULT_COMMAND='fd --type f --hidden --strip-cwd-prefix --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --strip-cwd-prefix --exclude .git'

export FZF_DEFAULT_OPTS='
  --height=60%
  --layout=reverse
  --border=rounded
  --prompt="❯  "
  --pointer="➔ "
  --preview-window=right:65%:wrap:border-left
'

export FZF_CTRL_R_OPTS='
  --prompt="History ❯ "
  --sort
'

export _FZF_PREVIEW_CMD='bat --color=always --style=plain,numbers --line-range=:500 {}'
export FZF_CTRL_T_OPTS="--preview '$_FZF_PREVIEW_CMD'"
export FZF_ALT_C_OPTS="--preview 'eza --icons=always --tree --level=1 {}'"

# =========================================================
# Widget: Ctrl+F — file picker (no hidden files)
# =========================================================
_fzf_file_no_hidden() {
  local cmd result
  cmd="${FZF_DEFAULT_COMMAND/--hidden /}"
  result=$(eval "${cmd:-find . -type f}" | fzf --preview "$_FZF_PREVIEW_CMD") \
    && LBUFFER+="$result"
  zle reset-prompt
}
zle -N _fzf_file_no_hidden

# =========================================================
# Widget: Alt+Z — zoxide project jumper
# =========================================================
_fzf_zoxide_jump() {
  local result
  # zoxide query -l returns plain paths — use $result directly
  result=$(zoxide query -l | fzf \
    --no-sort \
    --prompt="Jump to Folder ❯ " \
    --preview="eza --icons=always --tree --level=1 {}")
  if [[ -n "$result" ]]; then
    cd "$result" || return
  fi
  zle reset-prompt
}
zle -N _fzf_zoxide_jump

# =========================================================
# Widget: Ctrl+R — custom history searcher
# =========================================================
_fzf_history_clean() {
  local result
  result=$(fc -rl 1 | awk '{$1=""; print substr($0,2)}' \
    | fzf --prompt="History ❯ " --query="$LBUFFER")
  if [[ -n "$result" ]]; then
    LBUFFER="$result"
  fi
  zle reset-prompt
}
zle -N _fzf_history_clean

# =========================================================
# Widget: Ctrl+G — tmux sessionizer
# =========================================================
_tmux_sessionizer() {
  local selected
  selected=$(find \
    "$HOME/Projects" "$HOME/dev" "$HOME/work" "$HOME/.config" \
    -mindepth 1 -maxdepth 2 -type d 2>/dev/null \
    | fzf --preview "eza --icons --tree --level=1 {} | head -20")

  [[ -z "$selected" ]] && zle reset-prompt && return

  local session_name
  session_name=$(basename "$selected" | tr '.' '_')

  if ! tmux has-session -t "$session_name" 2>/dev/null; then
    tmux new-session -ds "$session_name" -c "$selected"
  fi

  if [[ -n "$TMUX" ]]; then
    tmux switch-client -t "$session_name"
  else
    tmux attach-session -t "$session_name"
  fi
  zle reset-prompt
}
zle -N _tmux_sessionizer

# =========================================================
# Global utility: fif — find text inside files
# =========================================================
fif() {
  if [[ -z "$1" ]]; then
    echo "Usage: fif <search_term>"
    return 1
  fi
  rg --files-with-matches --no-messages "$1" | fzf \
    --height 80% \
    --layout=reverse \
    --border=rounded \
    --prompt="Text Match ❯ " \
    --preview "bat --style=numbers --color=always \
      --highlight-line \$(rg --line-number --no-messages \"$1\" {} \
        | cut -d: -f1 | head -n 1) {}" \
    --preview-window="right:65%:wrap:border-left"
}

# =========================================================
# Global utility: fbr — fuzzy git branch checkout
# =========================================================
fbr() {
  local branch
  branch=$(git branch --all 2>/dev/null | grep -v HEAD \
    | fzf --preview 'git log --oneline --color=always {1} | head -20' \
    | sed 's/.* //' | sed 's#remotes/[^/]*/##')
  [[ -n "$branch" ]] && git checkout "$branch"
}
