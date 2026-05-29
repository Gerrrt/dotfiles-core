#!/usr/bin/env bash
# tmux-sessionizer — fuzzy-find a project and create/switch to its tmux session
# Bound to: prefix + f in tmux.conf

SEARCH_DIRS=(
	"$HOME/Projects"
	"$HOME/dev"
	"$HOME/work"
	"$HOME/.config"
)

find_args=()
for d in "${SEARCH_DIRS[@]}"; do
	[[ -d "$d" ]] && find_args+=("$d")
done

if [[ ${#find_args[@]} -eq 0 ]]; then
	echo "No project directories found. Edit SEARCH_DIRS in tmux-sessionizer.sh"
	exit 1
fi

selected=$(find "${find_args[@]}" -mindepth 1 -maxdepth 2 -type d 2>/dev/null |
	fzf \
		--prompt="Project ❯ " \
		--preview="eza --icons --tree --level=1 {} | head -30" \
		--preview-window="right:50%:border-left")

[[ -z "$selected" ]] && exit 0

session_name=$(basename "$selected" | tr '[:upper:]' '[:lower:]' | tr ' .' '_')

if ! tmux has-session -t "$session_name" 2>/dev/null; then
	tmux new-session -ds "$session_name" -c "$selected"
fi

tmux switch-client -t "$session_name"
