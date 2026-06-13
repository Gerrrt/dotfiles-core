# Contributing to dotfiles-core

This repo is the **Core layer** — the config that is identical on every machine —
authored once here and vendored into each OS repo's `core/` via `git subtree`.
A change here fans out to all nine OS repos, so the bar is: _is this truly Core,
and is it healthy?_

## Is it actually Core?

Before adding anything, run the README's test. It belongs here **only** if:

- it is **identical on every machine** (not OS-specific), **and**
- it is **not offensive/engagement** tooling.

Otherwise it lives elsewhere:

| If it changes when…                                               | It belongs in…                                     |
| ----------------------------------------------------------------- | -------------------------------------------------- |
| the **operating system** changes (pkg manager, paths, clipboard)  | the OS repo (`dotfiles-{MacBook,Debian,Fedora,…}`) |
| **you as an operator** change (C2, wordlists, engagement layouts) | `dotfiles-Kali`                                    |
| neither — it's the same everywhere                                | **here**                                           |

## The manifest is the contract

`core.manifest` is the canonical inventory of what Core ships. Adding a new Core
file means adding its path to `core.manifest` in the same change — the audit
enforces this in both directions:

- every path listed in the manifest must exist on disk, and
- every tracked file must be either listed in the manifest or in the audit's
  repo-meta allowlist (docs, CI config, dev tooling).

Repo-meta and dev tooling (this file, `LICENSE`, `.github/`, `bin/sync-core.sh`,
`bin/audit-core.sh`, …) are **not** vendored into OS repos, so they live in the
allowlist in `bin/audit-core.sh` rather than the manifest.

## Run the audit before you push

`bin/audit-core.sh` is the test suite. It checks manifest↔filesystem drift,
executable-bit invariants, shell syntax (`bash -n` / `zsh -n`), `luacheck`, and
`shellcheck`. It degrades gracefully — a missing linter is skipped, not failed —
so it runs on a bare box as well as in CI.

```bash
./bin/audit-core.sh           # full run
./bin/audit-core.sh --quiet   # only skips/failures + summary
```

The same script runs in CI (`.github/workflows/ci.yml`) on every push and PR, so
local and CI share one definition of "healthy."

### Pre-commit (optional but recommended)

```bash
pip install pre-commit && pre-commit install
pre-commit run --all-files
```

This wires up `shellcheck`, the standard whitespace/shebang hooks, and the audit
itself at commit time. Two deliberate non-checks:

- **shfmt is not enforced.** The scripts here use an intentional compact
  one-liner style that `shfmt` would expand.
- **luacheck only runs via the audit** (from inside `nvim/`), because it
  discovers `.luacheckrc` by searching up from the working directory — run from
  the repo root it misses `nvim/.luacheckrc` and floods false "undefined vim"
  warnings.

## Conventions

- **Executable bits matter.** Anything invoked by path (the `bin/` and
  `tmux/scripts/` scripts, the maint runner) must be `+x`; the `zsh/*.zsh`
  modules are **sourced**, so they must stay non-executable. The audit asserts
  both, so a regression fails CI rather than reaching a machine.
- **Indentation** is 2-space across the tree (`.editorconfig`).
- **Keep OS-specific bits out.** Strip clipboard/paths/package-manager logic into
  the OS repo; Core stays portable.

## Adding a new Core file (checklist)

1. Confirm it's Core (the table above).
2. Drop it into the matching path.
3. Strip out anything OS-specific.
4. Add the path to `core.manifest`.
5. Wire the symlink into each OS repo's `bootstrap.sh` if it needs one.
6. `./bin/audit-core.sh` — green before you push.
7. `./bin/sync-core.sh` to vendor it into every OS repo.
