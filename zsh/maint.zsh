# core/zsh/maint.zsh
# ──────────────────────────────────────────────────────────────────────────────
# Control surface for the daily maintenance job (core/maint/dotfiles-maint.sh).
# Wires that script to whatever scheduler the box has, at a time you pick:
#   • Linux w/ systemd  → a `--user` systemd timer (Persistent: catches up if the
#                          machine was off at the scheduled time)
#   • macOS             → a launchd LaunchAgent (StartCalendarInterval)
#   • else (Alpine/Gentoo OpenRC, etc.) → a crontab line
#
#   maint-install [HH:MM]   install + enable (default 13:00)
#   maint-run               run it now, in the foreground
#   maint-log [N|-f]        show last N log lines (default 50), or follow
#   maint-status            when does it next run / is it enabled
#   maint-uninstall         remove the schedule
#
# LOAD ORDER: anywhere after tools; it only defines functions. (Pairs with
# update.zsh — that's the per-shell nudge; this is the scheduled apply.)
# ──────────────────────────────────────────────────────────────────────────────

# Absolute path to the runner, resolved relative to THIS file (survives the
# core/ subtree living inside each OS repo). %x = path of the file being sourced.
typeset -g _MAINT_SH="${${(%):-%x}:A:h}/../maint/dotfiles-maint.sh"
_MAINT_SH="${_MAINT_SH:A}"
typeset -g _MAINT_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-maint/maint.log"

_maint_scheduler() {
  if [[ "$OSTYPE" == darwin* ]]; then
    echo launchd
  elif [[ -d /run/systemd/system ]] && command -v systemctl >/dev/null 2>&1; then
    echo systemd
  elif command -v crontab >/dev/null 2>&1; then
    echo cron
  else echo none; fi
}

maint-install() {
  emulate -L zsh
  local when="${1:-13:00}"
  if [[ "$when" != <0-23>:<0-59> ]]; then
    echo "usage: maint-install [HH:MM]   (24h, e.g. 13:00)" >&2
    return 1
  fi
  local hh="${when%%:*}" mm="${when##*:}"
  if [[ ! -f "$_MAINT_SH" ]]; then
    echo "maint: runner not found at $_MAINT_SH" >&2
    return 1
  fi
  chmod +x "$_MAINT_SH" 2>/dev/null

  case "$(_maint_scheduler)" in
  systemd)
    local ud="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    mkdir -p "$ud"
    cat >"$ud/dotfiles-maint.service" <<EOF
[Unit]
Description=dotfiles daily maintenance (brew, plugins, nvim, mise)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/env bash $_MAINT_SH
EOF
    cat >"$ud/dotfiles-maint.timer" <<EOF
[Unit]
Description=Run dotfiles maintenance daily at $when

[Timer]
OnCalendar=*-*-* $hh:$mm:00
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
EOF
    systemctl --user daemon-reload
    systemctl --user enable --now dotfiles-maint.timer
    echo "✓ systemd user timer installed for $when. Next runs:"
    systemctl --user list-timers dotfiles-maint.timer --no-pager 2>/dev/null
    echo "  (headless/server box that you're not always logged into? run: loginctl enable-linger $USER)"
    ;;
  launchd)
    local plist="$HOME/Library/LaunchAgents/com.dotfiles.maint.plist"
    mkdir -p "${plist:h}" "${_MAINT_LOG:h}"
    cat >"$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.dotfiles.maint</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>$_MAINT_SH</string></array>
  <key>StartCalendarInterval</key>
  <dict><key>Hour</key><integer>$((10#$hh))</integer><key>Minute</key><integer>$((10#$mm))</integer></dict>
  <key>StandardOutPath</key><string>$_MAINT_LOG</string>
  <key>StandardErrorPath</key><string>$_MAINT_LOG</string>
  <key>RunAtLoad</key><false/>
</dict></plist>
EOF
    launchctl unload "$plist" 2>/dev/null
    launchctl load "$plist" && echo "✓ launchd agent installed for $when (com.dotfiles.maint)"
    ;;
  cron)
    local marker="# dotfiles-maint"
    (
      crontab -l 2>/dev/null | grep -vF "$marker"
      echo "$mm $hh * * * /usr/bin/env bash $_MAINT_SH $marker"
    ) | crontab -
    echo "✓ cron entry installed for $when"
    crontab -l 2>/dev/null | grep -F "$marker"
    ;;
  *)
    echo "maint: no supported scheduler (systemd/launchd/cron) found" >&2
    return 1
    ;;
  esac
}

maint-run() {
  echo "running $_MAINT_SH ..."
  /usr/bin/env bash "$_MAINT_SH"
}
maint-log() {
  [[ -r "$_MAINT_LOG" ]] || {
    echo "no log yet at $_MAINT_LOG"
    return 0
  }
  if [[ "$1" == (-f|--follow) ]]; then tail -f "$_MAINT_LOG"; else tail -n "${1:-50}" "$_MAINT_LOG"; fi
}
maint-status() {
  case "$(_maint_scheduler)" in
  systemd)
    systemctl --user list-timers dotfiles-maint.timer --no-pager 2>/dev/null
    systemctl --user status dotfiles-maint.service --no-pager 2>/dev/null | head -5
    ;;
  launchd) launchctl list 2>/dev/null | grep -i dotfiles || echo "not loaded" ;;
  cron) crontab -l 2>/dev/null | grep -F "# dotfiles-maint" || echo "no cron entry" ;;
  *) echo "no scheduler" ;;
  esac
}
maint-uninstall() {
  case "$(_maint_scheduler)" in
  systemd)
    systemctl --user disable --now dotfiles-maint.timer 2>/dev/null
    rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/dotfiles-maint."{service,timer}
    systemctl --user daemon-reload
    echo "✓ removed systemd timer"
    ;;
  launchd)
    local p="$HOME/Library/LaunchAgents/com.dotfiles.maint.plist"
    launchctl unload "$p" 2>/dev/null
    rm -f "$p"
    echo "✓ removed launchd agent"
    ;;
  cron)
    (crontab -l 2>/dev/null | grep -vF "# dotfiles-maint") | crontab -
    echo "✓ removed cron entry"
    ;;
  esac
}
