# core/zsh/plugins.zsh
# ──────────────────────────────────────────────────────────────────────────────
# Lightweight zsh plugin loader — no Oh My Zsh, no Zinit. Plugins are auto-cloned
# to ${ZDOTDIR:-~/.config/zsh}/plugins on first launch (gitignored). Portable:
# needs git + network on first run only. Load AFTER fzf.zsh + bindings.zsh so the
# vi-mode init fires the binding hook with the widgets already defined, and AFTER
# options.zsh (which ran compinit — required by fzf-tab AND carapace).
#
# 2026 refresh:
#   • zsh-defer (romkatv) async-loads the two heaviest plugins (autosuggestions +
#     fast-syntax-highlighting) AFTER the first prompt paints — the shell is
#     interactive instantly and they "catch up" a few ms later.
#   • carapace (multi-shell completion, 500+ commands) feeds INTO fzf-tab.
# ──────────────────────────────────────────────────────────────────────────────

ZPLUGINDIR="${ZDOTDIR:-$HOME/.config/zsh}/plugins"

# Optional third arg: override the sourced filename
_zplugin_load() {
  local repo="${1}" name="${2}" srcfile="${3:-}"
  local plugin_path="${ZPLUGINDIR}/${name}"

  if [[ ! -d "$plugin_path" ]]; then
    mkdir -p "$ZPLUGINDIR"
    echo "Installing ${name}..."
    git clone --depth=1 "https://github.com/${repo}/${name}" "$plugin_path" ||
      {
        echo "ERROR: failed to install ${name}" >&2
        return 1
      }
  fi

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

# ── zsh-defer FIRST, so we can defer the heavy plugins below ──────────────────
_zplugin_load romkatv zsh-defer
# helper: defer if zsh-defer loaded, else load synchronously (bare-box safe)
_defer_or_now() {
  if (($+functions[zsh - defer])); then zsh-defer _zplugin_load "$@"; else _zplugin_load "$@"; fi
}

# =========================================================
# Plugins
# =========================================================
# Loaded NOW (define widgets / keybindings the vi-mode hook + bindings.zsh need):
_zplugin_load zsh-users zsh-history-substring-search
_zplugin_load jeffreytse zsh-vi-mode

# DEFERRED (heavy; not needed before the first prompt). NOTE: autosuggest-toggle
# (bound to Ctrl-\ in bindings.zsh) is now guarded there, since the widget may not
# exist yet at vi-mode init time.
_defer_or_now zsh-users zsh-autosuggestions
_defer_or_now zdharma-continuum fast-syntax-highlighting

# ── carapace: multi-shell completion engine (feeds fzf-tab). After compinit. ──
if [[ -n ${HAVE_CARAPACE:-} ]]; then
  export CARAPACE_BRIDGES='zsh,fish,bash' # borrow completions a tool ships for another shell
  zstyle ':completion:*' format $'\e[2;37m── %d ──\e[m'
  source <(carapace _carapace zsh)
fi

# fzf-tab (load after compinit + carapace, before other completion wrappers)
_zplugin_load Aloxaf fzf-tab
if (($+functions[fzf - tab - complete])); then
  zstyle ':fzf-tab:*' fzf-command fzf
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --icons --tree --level=1 $realpath'
  zstyle ':fzf-tab:complete:*:*' fzf-preview '$_FZF_PREVIEW_CMD $realpath 2>/dev/null'
  zstyle ':fzf-tab:*' switch-group '<' '>'
fi

# zsh-you-should-use — reminds you of aliases when typing full commands
_defer_or_now MichaelAquilina zsh-you-should-use you-should-use.plugin.zsh
export YSU_MESSAGE_POSITION="after"
export YSU_MODE="BESTMATCH"
export YSU_IGNORED_ALIASES=("ls" "ll" "la" "cd" "-")
