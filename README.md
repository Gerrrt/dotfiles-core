# dotfiles-core

**Single source of truth for the Core layer** shared across every machine repo.
This is the keystone of a nine-repo dotfiles system. It holds the config that is
identical everywhere — shell modules, tmux base, Neovim, git — and nothing that
is OS-specific or offensive.

> If it changes when the _operating system_ changes, it does **not** belong here.
> If it changes when _you as an operator_ change, it does **not** belong here.
> Everything left over is Core, and it lives here.

---

## The three-layer model (unchanged, now centralized)

| Layer                | Lives in                                                               | Examples                                        |
| -------------------- | ---------------------------------------------------------------------- | ----------------------------------------------- |
| **Core**             | **this repo**, vendored into each OS repo via `git subtree`            | zsh modules, tmux base, nvim, git/delta         |
| **OS-native**        | `dotfiles-{MacBook,Windows,Debian,Fedora,Arch,openSUSE,Alpine,Gentoo}` | package manager, clipboard shim, paths          |
| **Role / offensive** | `dotfiles-Kali`                                                        | engagement scaffolding, C2, Impacket, wordlists |

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
./scripts/sync-core.sh          # subtree-pulls main into all 9 OS repos
./scripts/sync-core.sh --dry-run
```

> Run `make` (no target) for a discoverable list of every entry point —
> `make setup` / `doctor` / `audit` / `test` / `bench` / `sync` / `hooks` all shell out
> to the `scripts/*.sh` dev tooling, which stays the single source of truth. (`make doctor`
> is the read-only triage half of `setup`; `bin/` holds only what ships — `clip`/`clip-paste`;
> the gate scripts live in `scripts/`.)

The OS repo's `bootstrap.sh` then symlinks `core/zsh/*.zsh`, `core/tmux/`,
`core/nvim/`, `core/git/`, `core/starship/`, `core/mise/`, and `core/bin/` into
place alongside its own OS-native files. (`core/bin/` is just `clip`/`clip-paste`
now — the dev scripts in `core/scripts/` are repo tooling and aren't symlinked.)

---

## Why subtree (not submodule, not chezmoi)

- **vs submodule** — submodules store a _pointer_, so a fresh clone is empty
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

```text
bin/                      SHIPPED — vendored into every OS repo (in core.manifest):
  clip                    cross-OS "copy to clipboard"   (WSL/macOS/Wayland/X11)
  clip-paste              cross-OS "paste from clipboard"
lib/                      SHIPPED — vendored bash libraries (sourced, not run):
  ux.sh                   shared palette/glyphs/spinner — each OS repo's bootstrap.sh
                          sources this (the pre-shell installer can't load the zsh ui.zsh)
scripts/                  DEV TOOLING — runs the gate HERE, never vendored out:
  audit-core.sh           THE gate: manifest/exec-bit/syntax/lint/behavioral (CI + pre-commit run this)
  test-core.sh            behavioral suite: clip ladder + load-order smoke + functions + nvim load
  bench-core.sh           hermetic hyperfine benchmark of the canonical zsh load chain
  sync-core.sh            loop git-subtree pull across all OS repos (the maintain button)
  update-plugins.sh       roll the pinned zsh-plugin SHAs (zsh/plugins.zsh) to upstream HEAD
zsh/                      sourced by each OS repo's .zshrc loader, IN THIS ORDER:
  tools.zsh               detection + single init point (zoxide/starship/atuin/mise) — load FIRST
  ui.zsh                  terminal-UX primitives (_core_err/warn/ok/hint/confirm/spin) — gum-aware
  options.zsh             setopts + completion system (compinit, cached) + zstyles
  history.zsh             HISTFILE/HISTSIZE/SAVEHIST + history setopts + secret-ignore
  aliases.zsh             modern-CLI aliases, each guarded by tools.zsh detection
  git.zsh                 curated OMZ-style git aliases + git_main_branch helper
  functions.zsh           cross-OS shell functions (mkcd, extract, up, ...)
  fzf.zsh                 fzf env + zle widgets (Ctrl-F/R, Alt-Z, Ctrl-G) + fif/fbr
  bindings.zsh            vi-mode keybindings (zvm_after_init hook)
  plugins.zsh             lightweight plugin loader + plugin list
  op.zsh                  1Password CLI helpers
  maint.zsh               daily-maintenance control surface (maint-install/run/log)
  update.zsh              `up` updater + once/day "updates available" nudge
  completions/            autoloaded completions for Core's verbs (up/extract/mkcd/…) — fpath-added by options.zsh
starship/
  starship.toml           prompt theme -> symlinked to ~/.config/starship.toml
mise/
  config.toml             global runtime versions (node/python/ruby/go/rust/java/lua)
sesh/
  sesh.toml.example       portable session-manager config (seeded, not symlinked)
tmux/
  tmux.conf               portable base config (OS bits -> os/<os>.conf)
  tmux.reset.conf         the keybinding layer (prefix C-a lives here)
  scripts/                popup scripts: tmux-menu / tmux-scratch / tmux-sesh / tmux-netinfo
maint/
  dotfiles-maint.sh       the daily "update everything (that's safe)" runner
git/
  gitconfig               portable git config (OS + identity layered via [include])
  local.gitconfig.example identity template — seeded by bootstrap, never tracked
nvim/                     entire lazy.nvim tree: lua/gerrrt/{config,plugins,servers,utils}
core.manifest             the canonical list of Core files (drives sync + audits)
core.version              human-readable Core version stamp (read by `core-version`)
```

> Load order is load-bearing: `tools` inits atuin (registers its widget), `options`
> runs `compinit` (fzf-tab + carapace need it), and `fzf` defines its zle widgets
> BEFORE `plugins` loads zsh-vi-mode, whose init fires the keybinding hook in
> `bindings`. `ui` loads right after `tools` (it only defines the `_core_*` UX
> helpers every later module may call). Each OS repo's `.zshrc` sources them as
> `tools → ui → options → history → aliases → git → functions → fzf → bindings →
plugins → op → maint → update → os → local` (the canonical order in
> `core.manifest`).

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
6. `./scripts/sync-core.sh` to push it into every OS repo's vendored `core/`.
