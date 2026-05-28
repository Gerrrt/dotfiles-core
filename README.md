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
`core/nvim/`, `core/git/` into place alongside its own OS-native files.

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

```
bin/
  sync-core.sh        loop git-subtree pull across all OS repos (the maintain button)
zsh/
  tools.zsh           tool detection + the POSIX-vs-modern guard (load FIRST)
  aliases.zsh         modern-CLI aliases, each guarded by tools.zsh detection
  functions.zsh       cross-OS shell functions (mkcd, extract, up, ...)
core.manifest         the canonical list of Core files (drives sync + audits)
```

> `tmux/`, `nvim/`, and `git/` are intentionally not re-derived here yet —
> promote your battle-tested versions up from `dotfiles-MacBook`/`dotfiles-Debian`
> into this repo so the canonical copy is the one you already trust.

---

## Promotion checklist (moving existing Core in)

1. Pick the most current copy of each Core file (likely MacBook or Debian).
2. Drop it into the matching path here (`zsh/`, `tmux/`, `nvim/`, `git/`).
3. Strip anything OS-specific into the OS repo (clipboard, paths, pkg manager).
4. Strip anything offensive into `dotfiles-Kali`.
5. Add the path to `core.manifest`.
6. `git subtree add` this repo into each OS repo, wire the symlinks in bootstrap.
7. From then on: edit here → `./bin/sync-core.sh` → done.
