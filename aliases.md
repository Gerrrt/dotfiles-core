# Aliases Cheat Sheet

> Last updated: 2026-06-26.
> Sources (repo-qualified — most live in sibling repos, not here): `core/zsh/aliases.zsh` ·
> `core/zsh/git.zsh` · `dotfiles-MacBook/os/macos.zsh` · `dotfiles-Kali/os/kali.zsh` ·
> `dotfiles-Kali/offensive/offensive.zsh` · `dotfiles-Fedora/os/fedora.zsh` ·
> `dotfiles-Arch/os/arch.zsh` · `dotfiles-Alpine/os/alpine.zsh` ·
> `dotfiles-Gentoo/os/gentoo.zsh` · `dotfiles-openSUSE/os/opensuse.zsh` ·
> `dotfiles-Windows/powershell/core/00-aliases.ps1`

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
- [Linux OS — Common (all distros)](#linux-os--common-all-distros)
- [Fedora — dnf & SELinux](#fedora--dnf--selinux)
- [Arch — pacman & AUR](#arch--pacman--aur)
- [Alpine — apk & doas](#alpine--apk--doas)
- [Gentoo — emerge & Portage](#gentoo--emerge--portage)
- [openSUSE — zypper & AppArmor](#opensuse--zypper--apparmor)
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

Source: `core/zsh/aliases.zsh` (plus `cheat`, from `core/zsh/functions.zsh`)

| Alias | Expands to | Notes |
| ------- | ------------ | ------- |
| `vim` | `nvim` | Always active (bootstrap ensures nvim) |
| `lg` | `lazygit` | Always active |
| `notes` | `cd "$NOTES_DIR" && nvim .` | Opens `$NOTES_DIR` (default: `~/Notes`) |
| `cheat` | `core-help` | Alias to the Core cheat sheet function (defined in `functions.zsh`) |

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
| `pullall [dir]` | Pull every git repo under a directory in parallel (auto-stash, fast-forward trunk, prune). Dir defaults to `$PULLALL_DIR` or `$PWD` |
| `fif <text>` | Find text inside files with ripgrep + fzf + preview (needs `rg` + `fzf`). Source: `core/zsh/fzf.zsh` |
| `fbr` | Fuzzy git-branch checkout (local + remote). Source: `core/zsh/fzf.zsh` |
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
| `htp` | `${EDITOR:-nvim} "$HOME/hacktheplanet"` | ⚠ guarded: symlink must exist — CTF/HTB command cheatsheet (fold with `za`) |
| `xdev` | `${EDITOR:-nvim} "$HOME/exploitdev"` | ⚠ guarded: symlink must exist — binary exploitation companion (stack/SEH/shellcode) |
| `evade` | `${EDITOR:-nvim} "$HOME/evasion"` | ⚠ guarded: symlink must exist — defense-evasion companion (AV/AMSI/C2/AD) |
| `ipp` | `${EDITOR:-nvim} "$HOME/ippsec"` | ⚠ guarded: symlink must exist — IppSec method (recon loop, shell stabilization, pseudo-shell patterns) |

### Key Functions

| Function | Description |
| ---------- | ------------- |
| `nmapsweep <target/CIDR>` | Conservative nmap `-sCV -T4` sweep; writes all formats into `./nmap/<target>.{nmap,gnmap,xml}` |
| `bhce <dc-ip> <user> <pass/:hash> [domain]` | BloodHound CE collection via NetExec; drops zip into `$ENGAGEMENT/loot/bloodhound/` |
| `mkengagement <name>` | Create dated engagement workspace (`$ENGAGEMENTS_DIR/YYYYMMDD-<name>`), set `$ENGAGEMENT`, open `scope.txt` first |
| `eng` | fzf-jump between existing engagement directories; sets `$ENGAGEMENT` |
| `logshell` | Record a full shell session (typescript + timing) into `$ENGAGEMENT/notes/` for audit trail |
| `cde` | `cd` back to the active engagement directory (`$ENGAGEMENT`); errors if none set |
| `note [msg]` | Append a timestamped line to `$ENGAGEMENT/notes.md`; with no args opens notes in `$EDITOR` |
| `lhost [iface]` | Print attacker IP — prefers VPN tun (tun0/wg0), falls back to default-route source; pass iface to force one |
| `ttyup` | Print the IppSec TTY-upgrade sequence (python pty → Ctrl-Z → `stty raw -echo; fg`) with your terminal rows/cols filled in |
| `rocks <keyword…>` | Open ippsec.rocks search in the browser for a technique or keyword |

### Key Environment Variables

| Variable | Default | Purpose |
| ---------- | --------- | --------- |
| `$ENGAGEMENTS_DIR` | `~/engagements` | Root for all engagement workspaces |
| `$SECLISTS_DIR` | `/usr/share/seclists` | SecLists wordlists tree |
| `$WORDLISTS_DIR` | `/usr/share/wordlists` | General wordlists (rockyou, etc.) |
| `$ENGAGEMENT` | *(set by `mkengagement`/`eng`)* | Current active engagement root |

---

## Linux OS — Common (all distros)

The following aliases are present in **every** Linux OS repo (Kali, Fedora, Arch,
Alpine, Gentoo, openSUSE). They're documented per-distro above/below but share
identical definitions. Source: each distro's `os/<distro>.zsh`.

| Alias | Expands to | Notes |
| ------- | ------------ | ------- |
| `pbcopy` | `clip` | ⚠ guarded: Core's `clip` script; on WSL calls `clip.exe` |
| `pbpaste` | `clip-paste` | ⚠ guarded: Core's `clip-paste` script |
| `localip` | `ip -brief -4 addr show scope global` | LAN IP across all Linux distros |
| `dotsync` | `cd "$HOME/dotfiles-<Distro>"` | Jump to this machine's dotfiles repo (distro-specific path) |
| `opsignin` | `eval "$(op signin)"` | ⚠ guarded: `op` — 1Password CLI sign-in |

**WSL-only** (set on all distros when running under WSL2):

| Alias | Expands to | Notes |
| ------- | ------------ | ------- |
| `open` | `explorer.exe` | Open a file or directory in Windows Explorer |
| `xdg-open` | `wslview` | ⚠ guarded: `wslview` — open URIs/files with the default Windows handler |
| `cdwin` | `cd "$WINHOME"` | Jump to Windows user home (set `WINHOME=/mnt/c/Users/<you>` in `local.zsh`) |

---

## Fedora — dnf & SELinux

Source: `dotfiles-Fedora/os/fedora.zsh`

### dnf Package Manager

dnf5 is the default since Fedora 41; commands are identical to dnf4.

| Alias | Expands to | Notes |
| ------- | ------------ | ------- |
| `dnfi` | `sudo dnf install` | Install a package |
| `dnfs` | `dnf search` | Search available packages |
| `dnfu` | `sudo dnf upgrade --refresh` | Sync metadata + full upgrade |
| `dnfr` | `sudo dnf remove` | Remove a package |
| `dnfh` | `dnf history` | Transaction history — undo-able |
| `dnfwhat` | `dnf provides` | Which package owns a file or command |

| Function | Description |
| ---------- | ------------- |
| `dnf-undo` | `sudo dnf history undo last` — roll back the most recent transaction |

### Flatpak

| Alias | Expands to |
| ------- | ------------ |
| `fpi` | `flatpak install flathub` |
| `fpu` | `flatpak update` |
| `fps` | `flatpak search` |
| `fpl` | `flatpak list --app` |

### SELinux helpers

Inert on WSL kernels (enforcement disabled); active on bare-metal / VM Fedora.

| Alias / Function | Description |
| ------- | ------------ |
| `se-status` | `sestatus` — show SELinux mode (with WSL fallback message) |
| `se-denials` | `sudo ausearch -m AVC,USER_AVC -ts recent` — recent AVC denials |
| `se-why` | `sudo journalctl -t setroubleshoot --since "10 min ago"` — human-readable denial explanations |
| `se-restore <path>` | `sudo restorecon -Rv <path>` — restore SELinux file contexts recursively |

---

## Arch — pacman & AUR

Source: `dotfiles-Arch/os/arch.zsh`

> ⚠ **Rolling release rule**: there is deliberately **no** `-Sy <pkg>` alias.
> Refreshing the sync DB without `-u` causes partial upgrades that break shared libraries.
> `pacu` always runs a full `-Syu`.

### pacman

| Alias | Expands to | Notes |
| ------- | ------------ | ------- |
| `pacu` | `sudo pacman -Syu` | **The only blessed upgrade** — full system update |
| `paci` | `sudo pacman -S --needed` | Install (skip if already installed) |
| `pacs` | `pacman -Ss` | Search remote repos |
| `pacqs` | `pacman -Qs` | Search installed packages |
| `pacr` | `sudo pacman -Rns` | Remove + unneeded deps + config files |
| `pacwhat` | `pacman -Qo` | Which package owns a file or command |
| `pacfiles` | `pacman -Ql` | List files installed by a package |
| `pacinfo` | `pacman -Qi` | Info on an installed package |
| `paclog` | `tail -n 50 /var/log/pacman.log` | Recent transactions |
| `pacout` | `checkupdates` | ⚠ guarded: `pacman-contrib` — list pending updates without touching sync DB |
| `paccacheclean` | `sudo paccache -rk2` | ⚠ guarded: `paccache` — keep last 2 cached versions per package |

| Function | Description |
| ---------- | ------------- |
| `pacorphans` | List + interactively remove orphaned packages (`pacman -Qtdq` → `pacman -Rns`) |
| `pacdowngrade <pkg>` | Show cached versions of `<pkg>` so you can reinstall an older one with `pacman -U /var/cache/…` |

### AUR Helper

| Alias | Expands to | Notes |
| ------- | ------------ | ------- |
| `aur` | `paru -S` or `yay -S` | ⚠ guarded: `paru` preferred; falls back to `yay` |
| `aurs` | `paru -Ss` or `yay -Ss` | Search AUR |
| `auru` | `paru -Sua` or `yay -Sua` | Upgrade AUR packages only |

### Flatpak

| Alias | Expands to |
| ------- | ------------ |
| `fpi` | `flatpak install flathub` |
| `fpu` | `flatpak update` |
| `fps` | `flatpak search` |
| `fpl` | `flatpak list --app` |

---

## Alpine — apk & doas

Source: `dotfiles-Alpine/os/alpine.zsh`

> Alpine uses **musl libc** — glibc-linked prebuilt binaries won't run; prefer `apk` packages or musl builds.
> Privilege tool is `doas`, not `sudo`; a compatibility shim is installed when `sudo` is absent.
> No Flatpak on Alpine by default.

### doas shim

| Alias | Expands to | Notes |
| ------- | ------------ | ------- |
| `sudo` | `doas` | ⚠ guarded: only set when `sudo` is absent and `doas` is present |

### apk Package Manager

The privilege prefix (`doas`/`sudo`/empty-for-root) is resolved once at shell
start into `$_ASU` and baked into the alias definitions.

| Alias | Expands to | Notes |
| ------- | ------------ | ------- |
| `apku` | `apk update && apk upgrade` | Sync + full upgrade (privilege prefix included) |
| `apki` | `apk add` | Install a package |
| `apkr` | `apk del` | Remove a package |
| `apks` | `apk search` | Search available packages |
| `apkw` | `apk info --who-owns` | Which package owns a file |
| `apkl` | `apk info -L` | List files installed by a package |
| `apkv` | `apk version` | Show upgradable packages |

> Note: `apk` has no transaction undo. Keep installs deliberate.

---

## Gentoo — emerge & Portage

Source: `dotfiles-Gentoo/os/gentoo.zsh`

> Source-based: `emerge` **compiles packages** — expect real build time and USE-flag decisions.
> Has a `doas` shim like Alpine (only active when `sudo` is absent).
> No Flatpak on Gentoo by default — Portage is the way.

### emerge / Portage

Installs default to `--ask` so you see the dep + USE plan before committing — this is the Gentoo habit.

| Alias | Expands to | Notes |
| ------- | ------------ | ------- |
| `emi` | `sudo emerge -av` | Install — ask + verbose (shows dep/USE plan) |
| `emu` | `sudo emerge -auvDN @world` | Update the whole `@world` set |
| `emr` | `sudo emerge -av --depclean` | Remove + clean orphaned deps (ask before running!) |
| `emsync` | `sudo emerge --sync` | Sync the Portage tree (slow on first run) |
| `emsearch` | `emerge -s` or `eix` | Search; `eix` (⚠ guarded) gives fast indexed results |
| `embelongs` | `equery belongs` | Which package owns a file (requires `gentoolkit`) |
| `emuses` | `equery uses` | Show a package's USE flags |
| `empreserved` | `sudo emerge @preserved-rebuild` | Rebuild packages linked against replaced libraries |
| `emconf` | `sudo dispatch-conf` | Merge pending `/etc` config updates (run after `emu`) |
| `gnews` | `sudo eselect news read` | Portage news — **read these**, they often contain breaking changes |

---

## openSUSE — zypper & AppArmor

Source: `dotfiles-openSUSE/os/opensuse.zsh`

> Two update commands for two flavors: `zup` (Leap — stable) vs `zdup` (Tumbleweed — rolling).
> Using the wrong one will half-update the system.

### zypper Package Manager

| Alias | Expands to | Notes |
| ------- | ------------ | ------- |
| `zref` | `sudo zypper refresh` | Sync repository metadata |
| `zin` | `sudo zypper install` | Install a package |
| `zrm` | `sudo zypper remove` | Remove a package |
| `zse` | `zypper search` | Search packages |
| `zup` | `sudo zypper up` | **Leap** — apply stable updates |
| `zdup` | `sudo zypper dup` | **Tumbleweed** — rolling dist-upgrade |
| `zwhat` | `zypper search --provides` | Which package provides a file or command |
| `zinfo` | `zypper info` | Show package information |
| `zlr` | `zypper repos` | List configured repositories |
| `snaps` | `sudo snapper list` | List Btrfs snapshots (zypper has no history undo — roll back via Btrfs snapshots instead) |

### Flatpak

| Alias | Expands to |
| ------- | ------------ |
| `fpi` | `flatpak install flathub` |
| `fpu` | `flatpak update` |
| `fps` | `flatpak search` |
| `fpl` | `flatpak list --app` |

### AppArmor helpers

openSUSE uses AppArmor (not SELinux). Inert on WSL kernels; active on bare-metal / VM.

| Alias / Function | Description |
| ------- | ------------ |
| `aa-status` | `sudo aa-status` — show AppArmor status (with WSL fallback message) |
| `aa-unconfined` | `sudo aa-unconfined` — list network processes without an AppArmor profile |
| `aa-complain <profile>` | Switch a profile to complain mode (log but don't enforce) |
| `aa-enforce <profile>` | Switch a profile back to enforce mode |

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

| Feature | zsh (Core / macOS / Linux) | PowerShell (Windows) | Reason |
| --------- | -------------------------- | ----------------------- | -------- |
| Markdown render | `md` → `glow --pager` | `gmd` → `glow` | `md` = `mkdir` alias on PS |
| Process viewer | `ps` → `procs` | `pss` → `procs` | `ps` = `Get-Process` on PS |
| Hex viewer | *(none)* | `hex` → `hexyl` | Windows addition |
| LOC counter | *(none)* | `loc` → `tokei` | Windows addition |
| Single-item listing | *(none)* | `l` → `eza -1` | Windows addition |
| Extra git status | *(none)* | `gs` = `git status -sb` | Windows-kept muscle memory |
| `rm` behavior | `rm -i` (Core); `trash` (macOS) | *(no override)* | macOS prefers recoverable Trash |
| `gap` (patch stage) | `git add --patch` | *(not present)* | Not yet ported to PowerShell |
| tmux auto-start | macOS: `exec tmux new-session -A -s main` | N/A | macOS uses `exec` so detach exits cleanly; all Linux OS layers use `attach \|\| new-session` (no `exec`), intentionally leaving a parent shell on detach for WSL recovery |
| Security module helpers | Fedora: SELinux (`se-*`); openSUSE: AppArmor (`aa-*`); Kali: none (offensive layer instead); Alpine/Gentoo: none | N/A | Each distro's default MAC framework |
| AUR helper | Arch only (`aur`, `aurs`, `auru`) | N/A | Arch-specific package ecosystem |
| Transaction undo | Fedora: `dnf-undo`; others: none | N/A | Only dnf5 has a true undo; Arch/openSUSE use cache/snapshots instead |

---

## Issues & Notes

The following inconsistencies were identified during this audit:

1. **All Linux OS layers use `attach || new-session` (no `exec`) in tmux auto-start**
   (`os/kali.zsh`, `os/fedora.zsh`, `os/arch.zsh`, `os/alpine.zsh`, `os/gentoo.zsh`,
   `os/opensuse.zsh`): macOS uses `exec tmux new-session -A -s main`, which replaces
   the login shell so detaching exits the terminal cleanly. All Linux layers use
   `tmux attach -t main 2>/dev/null || tmux new-session -s main` without `exec`,
   leaving a bare parent shell behind on detach. This is **intentional** for the WSL
   context (the parent shell provides a recovery shell if WSL kills the outer process),
   but differs from the macOS behaviour.

2. **`gap` not in PowerShell** (`powershell/core/00-aliases.ps1`): `gap` =
   `git add --patch` exists in Core zsh but has no Windows equivalent. Low
   priority since interactive staging in lazygit covers this, but the gap exists.

3. **`glol`/`glola` not in PowerShell**: The coloured graph-log aliases from
   `core/zsh/git.zsh` are missing from the PowerShell side.

4. **Fedora SELinux helpers inert on WSL**: `se-status`, `se-denials`, `se-restore`,
   and `se-why` are always defined in `fedora.zsh` regardless of WSL detection. They
   print a graceful "not active" message on WSL, so this is safe but slightly noisy.

5. **openSUSE `zup` vs `zdup` footgun**: Both aliases coexist. Running `zup` on
   Tumbleweed applies only patch-level updates (not the rolling upgrade); running `zdup`
   on Leap performs a dist-upgrade that may be unexpected. No guard exists — relies on
   user knowing their flavor.

6. **`cdwin` missing from `dotfiles-Kali/os/kali.zsh`**: Every other Linux OS repo
   (Fedora, Arch, Alpine, openSUSE, Gentoo) defines `cdwin` inside the WSL detection
   block, guarded on `WINHOME`: `[[ -n "${WINHOME:-}" ]] && alias cdwin='cd "$WINHOME"'`.
   `kali.zsh` omits it — likely an oversight since Kali is the primary WSL distro
   where this is most useful. Add the same guarded form inside `kali.zsh`'s
   `if (( _IS_WSL ))` block to keep parity; the guard ensures `cdwin` is inert
   when `WINHOME` is not set (e.g. bare-metal Kali).

---

Generated 2026-06-26 by `claude/alias-sync`.
