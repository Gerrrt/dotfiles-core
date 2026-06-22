# Aliases Cheat Sheet

> Last updated: 2026-06-22.
> Sources (repo-qualified — most live in sibling repos, not here): `core/zsh/aliases.zsh` ·
> `core/zsh/git.zsh` · `dotfiles-MacBook/os/macos.zsh` · `dotfiles-Kali/os/kali.zsh` ·
> `dotfiles-Kali/offensive/offensive.zsh` · `dotfiles-Windows/powershell/core/00-aliases.ps1`

Aliases marked **⚠ guarded** are only active when the backing tool is
installed; the classic command is the transparent fallback on a bare box.

---

## Contents

- [Core — Navigation & Files](#core--navigation--files)
- [Core — Viewing & Search](#core--viewing--search)
- [Core — System](#core--system)
- [Core — Network](#core--network)
- [Core — Editor & QoL](#core--editor--qol)
- [Core — Safety Nets](#core--safety-nets)
- [Core — Functions (key verbs)](#core--functions-key-verbs)
- [Core — Git](#core--git)
- [Core — Git (Fuzzy, needs fzf)](#core--git-fuzzy-needs-fzf)
- [macOS — Specific](#macos--specific)
- [Kali — OS Layer](#kali--os-layer)
- [Kali — Offensive Layer](#kali--offensive-layer)
- [Windows — PowerShell](#windows--powershell)
- [Cross-platform Intentional Differences](#cross-platform-intentional-differences)
- [Issues & Notes](#issues--notes)

---

## Core — Navigation & Files

Available on all platforms (macOS, Kali/Linux, Windows WSL).
Source: `core/zsh/aliases.zsh`

| Alias | Expands to | Notes |
| ------- | ------------ | ------- |
| `ls` | `eza --group-directories-first --icons=auto` | ⚠ guarded: `eza` |
| `ll` | `eza -lah --group-directories-first --icons=auto --git` | ⚠ guarded: `eza`; fallback `ls -lah` |
| `la` | `eza -a --group-directories-first --icons=auto` | ⚠ guarded: `eza`; fallback `ls -A` |
| `lt` | `eza --tree --level=2 --icons=auto` | ⚠ guarded: `eza` |
| `llt` | `eza --tree --level=3 -l --icons=auto` | ⚠ guarded: `eza` |
| `tree` | `eza --tree --icons=auto` | ⚠ guarded: `eza` |
| `cd` | `z` | ⚠ guarded: `zoxide` (smart directory jumper) |
| `cdi` | `zi` | ⚠ guarded: `zoxide` (interactive fzf jump) |
| `-` | `cd -` | Return to previous directory |
| `fm` | `yazi` | ⚠ guarded: `yazi` (TUI file manager) |
| `y` | `yazi` | ⚠ guarded: `yazi` (short form) |
| `mkdir` | `mkdir -p` | Always creates parent directories |

---

## Core — Viewing & Search

Source: `core/zsh/aliases.zsh`

| Alias | Expands to | Notes |
| ------- | ------------ | ------- |
| `cat` | `bat --paging=never` | ⚠ guarded: `bat` / `batcat` (Debian) |
| `catp` | `bat` | ⚠ guarded: `bat` / `batcat` — paged view |
| `fd` | `fd` / `fdfind` | ⚠ guarded: resolves `fd` on most distros, `fdfind` on Debian/Ubuntu |
| `rg` | `rg --smart-case` | ⚠ guarded: `rg` (ripgrep) |
| `md` | `glow --pager` | ⚠ guarded: `glow` — render Markdown in the terminal |
| `help` | `tldr` | ⚠ guarded: `tldr` / tealdeer — quick community reference |
| `dns` | `doggo` | ⚠ guarded: `doggo` — modern dig (DNS lookup) |
| `http` | `xh` | ⚠ guarded: `xh` — Rust HTTPie for API testing |
| `https` | `xh --https` | ⚠ guarded: `xh` |

---

## Core — System

Source: `core/zsh/aliases.zsh`

| Alias | Expands to | Notes |
| ------- | ------------ | ------- |
| `du` | `dust` | ⚠ guarded: `dust` — visual disk-usage tree |
| `ps` | `procs` | ⚠ guarded: `procs` — colourised, searchable process viewer |
| `top` / `htop` | `btop` | ⚠ guarded: `btop` |
| `watch` | `viddy` | ⚠ guarded: `viddy` — modern watch |
| `df` | `duf` | ⚠ guarded: `duf` — mountpoint-aware df; fallback `df -h` |
| `diff` | `diff --color=auto` | GNU diff only — probed once at load; BSD/macOS `diff` is NOT patched |

---

## Core — Network

Source: `core/zsh/aliases.zsh`

| Alias | Expands to | Notes |
| ------- | ------------ | ------- |
| `myip` | `curl -fsS https://ifconfig.me 2>/dev/null && echo` | Public IP lookup |
| `ports` | `ss -tulpn` or `netstat -tulpn` | Show all listening ports |
| `ping` | `gping` | ⚠ guarded: `gping` — graphical ping with live graph |

---

## Core — Editor & QoL

Source: `core/zsh/aliases.zsh`

| Alias | Expands to | Notes |
| ------- | ------------ | ------- |
| `vim` | `nvim` | Always active (bootstrap ensures nvim) |
| `lg` | `lazygit` | Always active |
| `notes` | `cd "$NOTES_DIR" && nvim .` | Opens `$NOTES_DIR` (default: `~/Notes`) |
| `cheat` | `core-help` | Alias to the Core cheat sheet function |

---

## Core — Safety Nets

Source: `core/zsh/aliases.zsh`

These use POSIX flags and are intentionally NOT replaced with modern tools.

| Alias | Expands to | Notes |
| ------- | ------------ | ------- |
| `rm` | `rm -i` | Prompt before delete (overridden to `trash` on macOS when available) |
| `cp` | `cp -i` | Prompt before overwrite |
| `mv` | `mv -i` | Prompt before overwrite |

---

## Core — Functions (key verbs)

Shell functions, not aliases, but are the primary user-facing Core commands.
Source: `core/zsh/functions.zsh` · `core/zsh/maint.zsh` · `core/zsh/update.zsh`

| Command | Description |
| --------- | ------------- |
| `mkcd <dir>` | Create directory (with parents) and `cd` into it |
| `cdup [n]` | Climb `n` directories (default 1); validates input |
| `extract <archive>` | Unpack any archive with tarbomb + clobber guards |
| `mkbak <file>` | Timestamped `.bak` copy before you edit |
| `fcd` | Fuzzy-cd into any subdirectory (needs fzf) |
| `serve [-l] [port]` | HTTP server in CWD (default port 8000); prints reachable URLs + QR; `-l` = loopback only |
| `genpw [length]` | Random alphanumeric password (default 16; openssl or /dev/urandom) |
| `please` | Re-run last command with sudo (previews + confirms first) |
| `core` / `core-help` | Core cheat sheet (filter: `core-help git`) |
| `core-doctor [-v]` | Health report — which tools are detected and wired |
| `core-version` | Print the vendored Core layer version |
| `up [-y]` | Apply package updates (interactive; confirms first) |
| `maint-install [HH:MM]` | Schedule the daily safe-update job (default 13:00) |
| `maint-run` | Run the daily maintenance job now |
| `maint-log [-f]` | View (or follow) the maintenance log |
| `maint-status` | When the job next runs and whether it is enabled |
| `maint-uninstall` | Remove the scheduled maintenance job |

---

## Core — Git

Source: `core/zsh/git.zsh`

OMZ-style git aliases, hand-curated. Two intentional safety upgrades over upstream
OMZ: `gpf` uses `--force-with-lease` (not raw `--force`); `gcm` is `commit --message`
(OMZ uses it for "checkout main"). Branch-aware aliases resolve the trunk via
`git_main_branch()`, so they work whether the repo uses `main`, `master`, `trunk`, etc.

### Status / Inspection

| Alias | Expands to |
| ------- | ------------ |
| `g` | `git` |
| `gst` | `git status` |
| `gss` | `git status --short` |
| `gsb` | `git status --short --branch` |

### Staging

| Alias | Expands to |
| ------- | ------------ |
| `ga` | `git add` |
| `gaa` | `git add --all` |
| `gap` | `git add --patch` |

### Committing

| Alias | Expands to | Notes |
| ------- | ------------ | ------- |
| `gc` | `git commit --verbose` | |
| `gcm` | `git commit --message` | |
| `gca` | `git commit --verbose --all` | |
| `gcam` | `git commit --all --message` | |
| `gc!` | `git commit --verbose --amend` | |
| `gcn!` | `git commit --verbose --no-edit --amend` | Keep existing message |

### Branching & Switching

| Alias | Expands to |
| ------- | ------------ |
| `gb` | `git branch` |
| `gba` | `git branch --all` |
| `gbd` | `git branch --delete` |
| `gbD` | `git branch --delete --force` |
| `gbm` | `git branch --move` |
| `gco` | `git checkout` |
| `gcb` | `git checkout -b` |
| `gcom` | `git checkout <main-branch>` |
| `gsw` | `git switch` |
| `gswc` | `git switch --create` |
| `gswm` | `git switch <main-branch>` |

### Diff & Log

| Alias | Expands to |
| ------- | ------------ |
| `gd` | `git diff` |
| `gds` | `git diff --staged` |
| `gdw` | `git diff --word-diff` |
| `glog` | `git log --oneline --decorate --graph` |
| `gloga` | `git log --oneline --decorate --graph --all` |
| `glol` | `git log --graph --pretty=coloured-oneline` |
| `glola` | `git log --graph --pretty=coloured-oneline --all` |

### Fetch / Push / Pull

| Alias | Expands to | Notes |
| ------- | ------------ | ------- |
| `gf` | `git fetch` | |
| `gfa` | `git fetch --all --prune --tags` | |
| `gl` | `git pull` | |
| `gpr` | `git pull --rebase` | |
| `gp` | `git push` | |
| `gpu` | `git push --set-upstream origin <branch>` | |
| `gpf` | `git push --force-with-lease` | **Safe force** — refuses to clobber unseen commits |
| `gpf!` | `git push --force` | Raw force, explicit opt-in |

### Stash

| Alias | Expands to |
| ------- | ------------ |
| `gsta` | `git stash push` |
| `gstaa` | `git stash push --include-untracked` |
| `gstp` | `git stash pop` |
| `gstl` | `git stash list` |
| `gstd` | `git stash drop` |

### Rebase

| Alias | Expands to |
| ------- | ------------ |
| `grb` | `git rebase` |
| `grbi` | `git rebase --interactive` |
| `grbm` | `git rebase <main-branch>` |
| `grbc` | `git rebase --continue` |
| `grba` | `git rebase --abort` |

### Reset / Restore / Remote / Merge

| Alias | Expands to |
| ------- | ------------ |
| `grh` | `git reset` |
| `grhh` | `git reset --hard` |
| `grs` | `git restore` |
| `grss` | `git restore --staged` |
| `gr` | `git remote` |
| `grv` | `git remote --verbose` |
| `gm` | `git merge` |
| `gma` | `git merge --abort` |

---

## Core — Git (Fuzzy, needs fzf)

Functions defined in `core/zsh/git.zsh`. Require `fzf`; degrade cleanly on bare boxes.

| Function | Description |
| ---------- | ------------- |
| `gaf` | Fuzzy `git add` — multi-select from modified + untracked; preview shows diff |
| `grf` | Fuzzy `git restore` — discard unstaged changes; multi-select |
| `grsf` | Fuzzy `git restore --staged` — unstage files; multi-select |

---

## macOS — Specific

Source: `dotfiles-MacBook/os/macos.zsh`

| Alias | Expands to | Notes |
| ------- | ------------ | ------- |
| `localip` | `ipconfig getifaddr en0` | LAN IP on the primary interface |
| `flushdns` | `sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder` | Flush DNS cache |
| `showfiles` | `defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder` | Show hidden files in Finder |
| `hidefiles` | `defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder` | Hide hidden files in Finder |
| `o` | `open` | Open file/directory in Finder / default app |
| `rm` | `trash` | ⚠ guarded: `trash` — send to Trash (overrides Core's `rm -i`) |
| `cheats` | `navi` | ⚠ guarded: `navi` — interactive fzf-driven cheatsheets |
| `masup` | `mas upgrade` | ⚠ guarded: `mas` — upgrade all App Store apps |
| `masls` | `mas list` | ⚠ guarded: `mas` — list installed App Store apps |
| `dotsync` | `cd "$HOME/dotfiles-MacBook"` | Jump to the MacBook dotfiles repo |
| `opsignin` | `eval "$(op signin)"` | ⚠ guarded: `op` — 1Password CLI sign-in |

---

## Kali — OS Layer

Source: `dotfiles-Kali/os/kali.zsh`

| Alias | Expands to | Notes |
| ------- | ------------ | ------- |
| `pbcopy` | `clip` | ⚠ guarded: Core's `clip` script (WSL: calls `clip.exe`) |
| `pbpaste` | `clip-paste` | ⚠ guarded: Core's `clip-paste` script |
| `localip` | `ip -brief -4 addr show scope global` | LAN IP (Linux / WSL) |
| `dotsync` | `cd "$HOME/dotfiles-Kali"` | Jump to the Kali dotfiles repo |
| `opsignin` | `eval "$(op signin)"` | ⚠ guarded: `op` — 1Password CLI sign-in |
| `open` | `explorer.exe` | WSL only — open in Windows Explorer |
| `xdg-open` | `wslview` | ⚠ guarded: `wslview` (WSL only) |
| `aptu` | `sudo apt-get update && sudo apt-get full-upgrade -y` | Full system upgrade |
| `apti` | `sudo apt-get install -y` | Install a package |
| `aptr` | `sudo apt-get remove` | Remove a package |
| `apts` | `apt-cache search` | Search packages |
| `aptw` | `dpkg -S` | Which package owns a file or command |
| `aptl` | `dpkg -L` | List files installed by a package |
| `aptshow` | `apt-cache show` | Show package details |

---

## Kali — Offensive Layer

Source: `dotfiles-Kali/offensive/offensive.zsh`

> ⚠ **These are for authorized engagements with written Rules of Engagement only.**
> Run `mkengagement` first — it creates `scope/scope.txt` before any tool runs.

### Tool Aliases

| Alias | Expands to | Notes |
| ------- | ------------ | ------- |
| `smb` | `nxc smb` | ⚠ guarded: `nxc` (NetExec — CrackMapExec successor) |
| `ldap` | `nxc ldap` | ⚠ guarded: `nxc` |
| `winrm` | `nxc winrm` | ⚠ guarded: `nxc` |
| `msf` | `msfconsole -q` | ⚠ guarded: `msfconsole` |
| `sliver` | `sliver-client` | ⚠ guarded: `sliver-client` |
| `hethttp` | `echo "serving …"; python3 -m http.server 8000` | Quick delivery web server on port 8000 in the current directory |
| `seclists` | `cd "$SECLISTS_DIR"` | Jump to `/usr/share/seclists` (guarded: dir must exist) |

### Key Functions

| Function | Description |
| ---------- | ------------- |
| `nmapsweep <target/CIDR>` | Conservative nmap `-sCV -T4` sweep; writes all formats into `./nmap/<target>.{nmap,gnmap,xml}` |
| `bhce <dc-ip> <user> <pass/:hash> [domain]` | BloodHound CE collection via NetExec; drops zip into `$ENGAGEMENT/loot/bloodhound/` |
| `mkengagement <name>` | Create dated engagement workspace (`$ENGAGEMENTS_DIR/YYYYMMDD-<name>`), set `$ENGAGEMENT`, open `scope.txt` first |
| `eng` | fzf-jump between existing engagement directories; sets `$ENGAGEMENT` |
| `logshell` | Record a full shell session (typescript + timing) into `$ENGAGEMENT/notes/` for audit trail |

### Key Environment Variables

| Variable | Default | Purpose |
| ---------- | --------- | --------- |
| `$ENGAGEMENTS_DIR` | `~/engagements` | Root for all engagement workspaces |
| `$SECLISTS_DIR` | `/usr/share/seclists` | SecLists wordlists tree |
| `$WORDLISTS_DIR` | `/usr/share/wordlists` | General wordlists (rockyou, etc.) |
| `$ENGAGEMENT` | *(set by `mkengagement`/`eng`)* | Current active engagement root |

---

## Windows — PowerShell

Source: `dotfiles-Windows/powershell/core/00-aliases.ps1`

> PowerShell function-backed aliases rather than `Set-Alias` throughout, so default
> flags can be baked in. A few names differ from the zsh equivalents to avoid
> shadowing PowerShell built-ins; see the comparison table below.

### File Listing

| Function | Expands to | Notes |
| ---------- | ------------ | ------- |
| `ls` | `eza --icons --group-directories-first` | ⚠ guarded: `eza`; fallback → `lsd` → `Get-ChildItem` |
| `l` | `eza --icons --group-directories-first -1` | ⚠ guarded: `eza` (no zsh equivalent) |
| `ll` | `eza --icons --group-directories-first -lh --git` | ⚠ guarded: `eza` |
| `la` | `eza --icons --group-directories-first -lha --git` | ⚠ guarded: `eza` |
| `lt` | `eza --icons --tree --level=2` | ⚠ guarded: `eza` |
| `llt` | `eza --icons --tree --level=3 -lh` | ⚠ guarded: `eza` |

### Modern CLI Tools

| Function | Expands to | Notes |
| ---------- | ------------ | ------- |
| `cat` | `bat --paging=never` | ⚠ guarded: `bat` |
| `catp` | `bat` | ⚠ guarded: `bat` — paged view |
| `grep` | `rg --smart-case` | ⚠ guarded: `rg` |
| `http` | `xh` | ⚠ guarded: `xh` |
| `https` | `xh --https` | ⚠ guarded: `xh` |
| `gmd` | `glow [--pager]` | ⚠ guarded: `glow` — **`gmd` not `md`** (avoids shadowing `mkdir`) |
| `dns` | `doggo` | ⚠ guarded: `doggo` |
| `du` | `dust` | ⚠ guarded: `dust` |
| `pss` | `procs` | ⚠ guarded: `procs` — **`pss` not `ps`** (avoids shadowing `Get-Process`) |
| `watch` | `viddy` | ⚠ guarded: `viddy` |
| `hex` | `hexyl` | ⚠ guarded: `hexyl` — coloured hex viewer (no zsh equivalent) |
| `loc` | `tokei` | ⚠ guarded: `tokei` — lines-of-code counter (no zsh equivalent) |
| `vim` | `nvim` (Set-Alias) | ⚠ guarded: `nvim` |
| `lg` | `lazygit` | ⚠ guarded: `lazygit` |

### Git (parity with `core/zsh/git.zsh`)

| Function | Expands to | Notes |
| ---------- | ------------ | ------- |
| `g` | `git` | |
| `gs` | `git status -sb` | Windows-only extra (same output as `gsb`) |
| `gst` | `git status` | |
| `gss` | `git status --short` | |
| `gsb` | `git status --short --branch` | |
| `ga` | `git add` | |
| `gaa` | `git add --all` | |
| `gc` | `git commit --verbose` | |
| `gcm` | `git commit -m` | |
| `gco` | `git checkout` | |
| `gd` | `git diff` | |
| `gl` | `git pull` | |
| `glog` | `git log --oneline --decorate --graph` | |
| `gp` | `git push` | |
| `lg` | `lazygit` | ⚠ guarded: `lazygit` |

### Navigation

| Function | Expands to |
| ---------- | ------------ |
| `..` | `Set-Location ..` |
| `...` | `Set-Location ..\..` |
| `....` | `Set-Location ..\..\..` |
| `~` | `Set-Location $HOME` |
| `mkcd <path>` | `New-Item -ItemType Directory -Force` then `Set-Location` |

### Utilities

| Function | Description |
| ---------- | ------------- |
| `which <name>` | Enhanced `Get-Command`; resolves external paths + shows kind for functions/aliases |
| `reload` | Re-dot-source `$PROFILE`; prints confirmation |
| `dotfiles` | `Set-Location $global:DOTFILES` (the repo root set by `install.ps1`) |

---

## Cross-platform Intentional Differences

| Feature | zsh (Core / macOS / Kali) | PowerShell (Windows) | Reason |
| --------- | -------------------------- | ----------------------- | -------- |
| Markdown render | `md` → `glow --pager` | `gmd` → `glow` | `md` = `mkdir` alias on PS |
| Process viewer | `ps` → `procs` | `pss` → `procs` | `ps` = `Get-Process` on PS |
| Hex viewer | *(none)* | `hex` → `hexyl` | Windows addition |
| LOC counter | *(none)* | `loc` → `tokei` | Windows addition |
| Single-item listing | *(none)* | `l` → `eza -1` | Windows addition |
| Extra git status | *(none)* | `gs` = `git status -sb` | Windows-kept muscle memory |
| `rm` behavior | `rm -i` (Core); `trash` (macOS) | *(no override)* | macOS prefers recoverable Trash |
| `gap` (patch stage) | `git add --patch` | *(not present)* | Not yet ported to PowerShell |
| tmux auto-start | macOS: `exec tmux new-session -A -s main` | N/A | macOS uses `exec` so detach exits cleanly; Kali omits `exec` and leaves a parent shell on detach |

---

## Issues & Notes

The following inconsistencies were identified during this audit:

1. **Kali tmux auto-start missing `exec`** (`os/kali.zsh`): The Kali tmux
   auto-start uses `tmux attach -t main 2>/dev/null || tmux new-session -s main`
   while macOS uses `exec tmux new-session -A -s main`. The Kali form leaves a
   parent shell behind when you detach. Consider aligning to the macOS `exec`
   pattern.

2. **`gap` not in PowerShell** (`powershell/core/00-aliases.ps1`): `gap` =
   `git add --patch` exists in Core zsh but has no Windows equivalent. Low
   priority since interactive staging in lazygit covers this, but the gap exists.

3. **`glol`/`glola` not in PowerShell**: The coloured graph-log aliases from
   `core/zsh/git.zsh` are missing from the PowerShell side.

---

Generated 2026-06-22 by `claude/alias-sync`.
