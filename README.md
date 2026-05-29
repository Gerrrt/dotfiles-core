# dotfiles-core

**Single source of truth for the Core layer** shared across every machine repo.
This is the keystone of a nine-repo dotfiles system. It holds the config that is
identical everywhere — shell modules, tmux base, Neovim, git — and nothing that
is OS-specific or offensive.

> If it changes when the *operating system* changes, it does **not** belong here.
> If it changes when *you as an operator* change, it does **not** belong here.
> Everything left over is Core, and it lives here.

---

## The three-layer model (unchanged, now centralized)

| Layer | Lives in | Examples |
|-------|----------|----------|
| **Core** | **this repo**, vendored into each OS repo via `git subtree` | zsh modules, tmux base, nvim, git/delta |
| **OS-native** | `dotfiles-{MacBook,Windows,Debian,Fedora,Arch,openSUSE,Alpine,Gentoo}` | package manager, clipboard shim, paths |
| **Role / offensive** | `dotfiles-Kali` | engagement scaffolding, C2, Impacket, wordlists |

Previously each repo carried its **own copy** of Core, and drift was caught
after the fact with `core-diff.sh`. That works at 4 repos. At 9 it doesn't.
This repo flips it: Core is authored **once, here**, then pulled into each OS
repo as a vendored `core/` subtree. No more N-way reconciliation.

---

## How an OS repo consumes Core

Each machine repo (e.g. `dotfiles-Fedora`) vendors this repo under `core/`:

```bash
# one-time, inside the OS repo:
git subtree add --prefix=core https://github.com/<you>/dotfiles-core main --squash
```

That physically copies Core into `core/` and commits it. The repo now clones
and works with **no submodule flags** — important, since these are public
showcase repos people will browse.

To update every OS repo after a Core change, run the loop helper from this repo:

```bash
./bin/sync-core.sh          # subtree-pulls main into all 9 OS repos
./bin/sync-core.sh --dry-run
```

The OS repo's `bootstrap.sh` then symlinks `core/zsh/*.zsh`, `core/tmux/`,
`core/nvim/`, `core/git/`, `core/starship/`, `core/mise/`, and `core/bin/` into
place alongside its own OS-native files.

---

## Why subtree (not submodule, not chezmoi)

- **vs submodule** — submodules store a *pointer*, so a fresh clone is empty
  until `git submodule update --init`. Subtree vendors the actual files, so
  every repo is self-contained and clone-and-go. Better for portfolio repos.
- **vs chezmoi** — chezmoi (one repo + per-OS templates) is the most DRY answer
  and is the right move if you ever want to collapse nine repos into one. It
  trades the nine-repo breadth-portfolio for minimalism. This system keeps the
  portfolio; switching to chezmoi later is a content migration, not a rewrite,
  because the Core files here are already plain and OS-agnostic.

---

## Layout

Core is fully populated — every layer below is authored here and synced out to
each OS repo's vendored `core/`. The canonical inventory is `core.manifest`;
this tree is the human-readable version of it.

```
bin/
  clip                    cross-OS "copy to clipboard"   (WSL/macOS/Wayland/X11)
  clip-paste              cross-OS "paste from clipboard"
  sync-core.sh            loop git-subtree pull across all OS repos (the maintain button)
zsh/                      sourced by each OS repo's .zshrc loader, IN THIS ORDER:
  tools.zsh               detection + single init point (zoxide/starship/atuin/mise) — load FIRST
  aliases.zsh             modern-CLI aliases, each guarded by tools.zsh detection
  functions.zsh           cross-OS shell functions (mkcd, extract, up, ...)
  fzf.zsh                 fzf env + zle widgets (Ctrl-F/R, Alt-Z, Ctrl-G) + fif/fbr
  bindings.zsh            vi-mode keybindings (zvm_after_init hook)
  plugins.zsh             lightweight plugin loader + plugin list
  op.zsh                  1Password CLI helpers
starship/
  starship.toml           prompt theme -> symlinked to ~/.config/starship.toml
mise/
  config.toml             global runtime versions (node/python/ruby/go/rust/java/lua)
tmux/
  tmux.conf               portable base config (OS bits -> os/<os>.conf)
  scripts/                popup scripts: tmux-menu / tmux-scratch / tmux-sessionizer
git/
  gitconfig               portable git config (OS + identity layered via [include])
  local.gitconfig.example identity template — seeded by bootstrap, never tracked
nvim/                     entire lazy.nvim tree: lua/gerrrt/{config,plugins,servers,utils}
core.manifest             the canonical list of Core files (drives sync + audits)
```

> Load order is load-bearing: `tools` inits atuin (registers its widget) and
> `fzf` defines its zle widgets BEFORE `plugins` loads zsh-vi-mode, whose init
> fires the keybinding hook in `bindings`. Each OS repo's `.zshrc` sources them
> as `tools → aliases → functions → fzf → bindings → plugins → op → os → local`.

---

## Adding a new file to Core

Core is already complete (zsh, tmux, nvim, git, starship, mise, and the clip
scripts are all here). The promotion from the old per-repo copies is done — so
this is now just the procedure for the occasional **new** Core file:

1. Confirm it's actually Core: identical on every machine, **not** OS-specific,
   **not** offensive. (OS-specific → the OS repo; offensive → `dotfiles-Kali`.)
2. Drop it into the matching path here.
3. Strip anything OS-specific out into the OS repo (clipboard, paths, pkg mgr).
4. Add the path to `core.manifest` — that's the contract the audits read.
5. Wire the symlink into each OS repo's `bootstrap.sh` if the file needs one.
6. `./bin/sync-core.sh` to push it into every OS repo's vendored `core/`.
