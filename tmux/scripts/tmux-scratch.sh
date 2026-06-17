#!/usr/bin/env bash

# Define session name for scratchpad
session="_popup_scratchpad"

# Create session if it doesn't exist
if ! tmux has -t "$session" 2>/dev/null; then
  session_id="$(tmux new-session -dP -s "$session" -F '#{session_id}')"
  tmux set-option -s -t "$session_id" key-table popup
  tmux set-option -s -t "$session_id" status off
  tmux set-option -s -t "$session_id" prefix None
  session="$session_id"
fi

# Attach to the scratchpad session inside the popup.
# display-popup launches this script with TERM UNSET (it does NOT inherit the calling
# pane's TERM), so the nested `tmux attach` finds no terminfo and dies with
# "open terminal failed: terminal does not support clear". Ensure a usable TERM first:
# keep a valid one if present, else fall back to tmux's default-terminal (tmux-256color),
# which exists wherever tmux runs. (No `>/dev/null`: a tmux client must render to the
# popup's terminal — redirecting its output away is what "open terminal failed" looks like.)
if [[ -z "${TERM:-}" ]] || ! infocmp "$TERM" >/dev/null 2>&1; then
  export TERM=tmux-256color
fi
exec tmux attach -t "$session"
