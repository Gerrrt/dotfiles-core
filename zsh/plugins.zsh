# core/zsh/plugins.zsh
# Lightweight zsh plugin loader — no Oh My Zsh, no Zinit. Plugins are auto-cloned
# to ${ZDOTDIR:-~/.config/zsh}/plugins on first launch (gitignored). Portable:
# needs git + network on first run only. Load AFTER fzf.zsh + bindings.zsh so the
# vi-mode init fires the binding hook with the widgets already defined.

ZPLUGINDIR="${ZDOTDIR:-$HOME/.config/zsh}/plugins"

# Optional third arg: override the sourced filename
# Needed for plugins whose main file doesn't match the repo name
_zplugin_load() {
  local repo="${1}"
  local name="${2}"
  local srcfile="${3:-}"
  local plugin_path="${ZPLUGINDIR}/${name}"

  if [[ ! -d "$plugin_path" ]]; then
    mkdir -p "$ZPLUGINDIR"
    echo "Installing ${name}..."
    git clone --depth=1 "https://github.com/${repo}/${name}" "$plugin_path" \
      || { echo "ERROR: failed to install ${name}" >&2; return 1; }
  fi

  # Source override file if provided
  if [[ -n "$srcfile" ]] && [[ -f "${plugin_path}/${srcfile}" ]]; then
    source "${plugin_path}/${srcfile}"
  elif [[ -f "${plugin_path}/${name}.plugin.zsh" ]]; then
    source "${plugin_path}/${name}.plugin.zsh"
  elif [[ -f "${plugin_path}/${name}.zsh" ]]; then
    source "${plugin_path}/${name}.zsh"
  elif [[ -f "${plugin_path}/${name}.sh" ]]; then
    source "${plugin_path}/${name}.sh"
  elif [[ -f "${plugin_path}/fsh.plugin.zsh" ]]; then
    source "${plugin_path}/fsh.plugin.zsh"
  fi
}

function zplugin-update {
  local dir name
  for dir in "${ZPLUGINDIR}"/*/; do
    if [[ -d "$dir" ]]; then
      name=$(basename "$dir")
      echo "Updating ${name}..."
      git -C "$dir" pull --ff-only 2>/dev/null
    fi
  done
}

# =========================================================
# Plugins
# =========================================================
_zplugin_load zsh-users        zsh-autosuggestions
_zplugin_load zsh-users        zsh-history-substring-search
_zplugin_load jeffreytse       zsh-vi-mode
_zplugin_load zdharma-continuum fast-syntax-highlighting

# fzf-tab (load after compinit, before other completion wrappers)
_zplugin_load Aloxaf fzf-tab
if (( $+functions[fzf-tab-complete] )); then
  zstyle ':fzf-tab:*' fzf-command fzf
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --icons --tree --level=1 $realpath'
  zstyle ':fzf-tab:complete:*:*' fzf-preview '$_FZF_PREVIEW_CMD $realpath 2>/dev/null'
  zstyle ':fzf-tab:*' switch-group '<' '>'
fi

# zsh-you-should-use — reminds you of aliases when typing full commands
_zplugin_load MichaelAquilina zsh-you-should-use you-should-use.plugin.zsh
export YSU_MESSAGE_POSITION="after"
export YSU_MODE="BESTMATCH"
# Don't nag about common navigation aliases
export YSU_IGNORED_ALIASES=("ls" "ll" "la" "cd" "-")
