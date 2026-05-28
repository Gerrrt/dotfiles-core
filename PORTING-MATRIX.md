# Distro Porting Matrix

How to stamp `dotfiles-Arch`, `dotfiles-openSUSE`, `dotfiles-Alpine`, and
`dotfiles-Gentoo` from the `dotfiles-Fedora` template. The structure is identical
every time — only three things change per distro: **package manager commands**,
**package names**, and **distro quirks**. Core never changes (it's vendored).

## Per-repo recipe

1. `cp -r dotfiles-Fedora dotfiles-<Distro>`
2. Rename `os/fedora.zsh` → `os/<distro>.zsh`; swap clipboard + pkg-manager aliases.
3. Replace `install/packages.txt` with that distro's names (table below).
4. In `bootstrap.sh`: swap the `dnf` block for the distro's installer and the
   `/etc/os-release` guard string.
5. `git subtree add --prefix=core <dotfiles-core> main --squash`
6. Update the README's "specifics" section to that distro's quirks.

## Package-manager commands

| Action | Arch | openSUSE | Alpine | Gentoo |
|---|---|---|---|---|
| refresh | `sudo pacman -Sy` | `sudo zypper refresh` | `doas apk update` | `sudo emerge --sync` |
| upgrade | `sudo pacman -Syu` | Leap: `zypper up` · **Tumbleweed: `zypper dup`** | `doas apk upgrade` | `sudo emerge -uDN @world` |
| install | `sudo pacman -S <pkg>` | `sudo zypper in <pkg>` | `doas apk add <pkg>` | `sudo emerge <atom>` |
| remove | `sudo pacman -Rns <pkg>` | `sudo zypper rm <pkg>` | `doas apk del <pkg>` | `sudo emerge --depclean <atom>` |
| search | `pacman -Ss <term>` | `zypper se <term>` | `apk search <term>` | `emerge -s <term>` |
| owns-file | `pacman -Qo <path>` | `zypper se --provides <f>` | `apk info --who-owns <f>` | `equery belongs <path>` |

## Package names (modern CLI stack)

| Tool | Arch | openSUSE | Alpine | Gentoo (atom) |
|---|---|---|---|---|
| eza | `eza` | `eza` | `eza` | `sys-apps/eza` |
| bat | `bat` | `bat` | `bat` | `sys-apps/bat` |
| fd | `fd` | `fd` | `fd` | `sys-apps/fd` |
| ripgrep | `ripgrep` | `ripgrep` | `ripgrep` | `sys-apps/ripgrep` |
| zoxide | `zoxide` | `zoxide` | `zoxide` | `app-shells/zoxide` |
| fzf | `fzf` | `fzf` | `fzf` | `app-shells/fzf` |
| git-delta | `git-delta` | `git-delta` | `delta` | `dev-util/git-delta` |
| btop | `btop` | `btop` | `btop` | `sys-process/btop` |
| tldr | `tealdeer` | `tealdeer`¹ | `tealdeer` | `app-misc/tealdeer` |
| neovim | `neovim` | `neovim` | `neovim` | `app-editors/neovim` |
| lazygit | `lazygit` | `lazygit` | `lazygit` | `dev-vcs/lazygit` |
| zsh | `zsh` | `zsh` | `zsh`² | `app-shells/zsh` |
| tmux | `tmux` | `tmux` | `tmux` | `app-misc/tmux` |
| starship | `starship` | script³ | script³ | `app-shells/starship` |
| atuin | `atuin` (AUR for some) | script³ | `atuin` | `app-shells/atuin` |
| yazi | `yazi` | cargo³ | cargo³ | `app-misc/yazi` |

¹ openSUSE: may be in `devel` repos; if absent, `cargo install tealdeer`.
² Alpine default shell is `ash`; you must `apk add zsh` explicitly.
³ Not packaged or stale → use the upstream installer / `cargo install` (same
  pattern bootstrap.sh already uses on Fedora). Add `cargo`/`rust` to packages.

## Clipboard backend (swap in `os/<distro>.zsh`)

| Distro | Wayland | X11 fallback |
|---|---|---|
| Arch | `wl-clipboard` (`wl-copy`/`wl-paste`) | `xclip` |
| openSUSE | `wl-clipboard` | `xclip` |
| Alpine | `wl-clipboard` | `xclip` / `xsel` (often headless — may be neither) |
| Gentoo | `gui-apps/wl-clipboard` | `x11-misc/xclip` |

## Distro quirks worth a README note (and that will actually bite you)

**Arch** — Rolling release; update often or not at all (partial upgrades break
things — never `-Sy <pkg>` without `-u`). Most modern tools are in official
repos; the rest are one `paru -S` away in the AUR. Enable `multilib` if you'll
run 32-bit/Wine tooling. Cleanest distro for this stack.

**openSUSE** — Two flavors, and the update command differs: **Tumbleweed**
(rolling) uses `zypper dup`, **Leap** (stable) uses `zypper up`. Get this wrong
and you either don't update or you half-update. Add the **Packman** repo (the
openSUSE analog to RPM Fusion) for codecs. `zypper` has the best dependency
solver of any of these — lean on it.

**Alpine** — The real outlier: **musl libc, not glibc.** Prebuilt binaries
linked against glibc (some `cargo`-less installer scripts, some vendor blobs)
**will not run** — prefer `apk` packages or musl-target builds. Default shell is
`ash` (busybox), default privilege tool is `doas` (not `sudo`), and many
"classic" commands are busybox applets with fewer flags. This is your
small-footprint / container / rescue-disk distro — keep its layer lean and don't
fight the musl grain.

**Gentoo** — Source-based: `emerge` **compiles** packages, so expect real build
time (mitigate with binary packages via a binhost, and tune `MAKEOPTS`). **USE
flags** gate features at compile time — this is the whole point of Gentoo and
where the learning is. Tool *names* are full atoms (`category/name`). Treat this
repo as your "understand the system from the ground up" build; it's the most
educational and the most time-expensive.

---

### Suggested stamping order (easiest learning curve → hardest)

1. **Arch** — almost everything is in-repo; closest to Fedora effort.
2. **openSUSE** — straightforward once you internalize `dup` vs `up`.
3. **Alpine** — forces you to reason about musl and minimalism (great for the
   container/rescue skills a red-teamer wants).
4. **Gentoo** — the capstone; USE flags + source builds teach you the most.
