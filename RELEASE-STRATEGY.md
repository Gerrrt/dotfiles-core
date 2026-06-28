# Release Strategy

How and when changes ship across the ten-repo fleet. This is the **policy
layer** that ties together the machinery already in the tree — `core.version`,
`scripts/release.sh`, `scripts/sync-core.sh`, the `core.lock` provenance stamp,
`scripts/fleet-drift.sh`, and the weekly bots — into one cadence, one tagging
discipline, and one safe-rollout path. When a rule here drifts from `README.md`
or `CONTRIBUTING.md`, those win; fix this.

The short version: **Core is the only thing that is versioned and released. The
OS and Role repos are consumers that pull a named Core version when they choose
to.** Releases are cut on a predictable monthly rhythm (plus out-of-band for
security), tagged `vX.Y.Z`, proven green by the audit before they fan out, and
rolled out canary-first so a bad Core can never reach all eight operating
systems at once.

## 1. The unit of release

The fleet is not eight things that each version themselves. It is **one
versioned thing (Core) vendored into thin per-OS consumers**:

- **Core** (`dotfiles-core`) carries the SemVer in `core.version` (currently
  `1.2.0`). It is the single source of truth, vendored into each OS repo's
  `core/` via `git subtree`. A defect here fans out N-way, so Core is the thing
  that earns a version number, a tag, and a changelog.
- **OS-native repos** (`dotfiles-{MacBook,Windows,Fedora,Arch,openSUSE,Alpine,Gentoo}`)
  and **Role repos** (`dotfiles-Kali`, `dotfiles-Defense`) are **not**
  independently versioned. They are stamped with the Core they carry — the
  generated `core.lock` records `core_version`, `core_sha`, and `core_branch` —
  so "what Core does Alpine run?" is answerable offline without a release
  number of its own.
- **`dotfiles-web`** documents the system; it ships when its content is true,
  not on this cadence.

This is deliberate. Versioning eight repos independently would multiply the
release surface eightfold for no benefit: the OS layer is a thin shim over
package manager, clipboard, and paths, and most of what changes a host is Core.

## 2. Release cadence

Three tracks moving at three speeds. Conflating them is what causes cascade
failures — keep them separate.

| Track | Trigger | Frequency | Tagged | Blast radius |
| --- | --- | --- | --- | --- |
| Continuous integration | every merge to `main` | per-merge | no | none until synced |
| Routine pin bumps | the freshness bot | weekly (Mon 06:00 UTC) | no | one PR to review |
| Tagged Core release | calendar + on-demand | monthly + security | `vX.Y.Z` | the whole fleet |

### Continuous (per-merge)

`main` is always green: `ci.yml` runs the audit on every push and PR, and the
fan-out gate in `sync-core.sh` refuses to vendor a red tree. Merging to `main`
is **not** a release — nothing reaches a host until a sync happens. This is what
lets you commit freely without fear of breaking a live machine.

### Routine (weekly, automated)

The weekly bots **report first** — they open a PR or a deduped issue and never
vendor anything on their own. They run on two offset slots so the reviews don't
all land at once:

- **Mondays 06:00 UTC** — `freshness.yml` (rolls the zsh-plugin + nvim pins
  forward as a PR) and `fleet-drift.yml` (flags any OS repo lagging Core's tip).
- **Tuesdays 07:00 UTC** — `claude-routines.yml` (`/doc-audit` + `/tool-scout`),
  deliberately offset a day behind freshness so its findings issue lands after
  that week's pin PR.

Plugin and nvim pin bumps are batched into the weekly freshness PR, never landed
per-tool, so the fleet sees one reviewed step a week rather than a trickle of
unaudited churn. A quiet week means nothing needs doing.

### Tagged releases (monthly + security)

Cut a tagged Core release **once a month** on a fixed day (e.g. the first
Monday, after that week's freshness PR has merged and baked on `main`), plus
**out-of-band** for a security fix or a regression that is actively biting a
host.

Why monthly is the sweet spot for an eight-OS fleet:

- **Weekly tags** would 8× the fan-out churn — every OS repo re-syncs, every
  host re-bootstraps — for changes that are mostly already on `main` and
  available to anyone who wants them early.
- **Quarterly tags** let Core drift far enough from the synced fleet that a
  sync becomes a big, risky catch-up instead of a small, boring one.
- **Monthly** keeps each release small enough to reason about and roll back,
  while giving the weekly pin bumps time to bake on `main` before they are
  frozen into a tag.

### SemVer, mapped to dotfiles

`release.sh` enforces clean `X.Y.Z` (no pre-release suffix) and a matching dated
CHANGELOG heading. Choose the bump by **blast radius on a host**, not by how big
the diff looks:

- **MAJOR** — a breaking change a host must adapt to: reordering the load chain,
  removing or renaming a public alias / binding / function, changing the
  `bootstrap.sh` symlink contract, or dropping a manifest path. These force
  action on every OS repo; flag them loudly in the CHANGELOG.
- **MINOR** — additive and backward-compatible: a new zsh module, a new alias,
  a new function, a new keybinding that displaces nothing.
- **PATCH** — a fix or doc change with no interface change, including a pin bump
  that does not change observable behavior.

## 3. Repository architecture

The question "`common/` + OS subdirectories, or heavy conditionals in one
`.zshrc`?" has a third answer, and it is the one already in use because the
first two break at eight-OS scale.

### Why the two common approaches fail here

- **One `.zshrc` full of `case "$OS"` branches.** Every host parses every other
  host's logic; BSD-vs-GNU coreutils, systemd-vs-OpenRC, and Windows paths do
  not reduce to clean conditionals; and a single typo in the shared file breaks
  *all* hosts at once. The blast radius is the whole fleet for every edit.
- **`common/` + `os/<name>/` in one monorepo.** Better — but every host still
  clones every OS's files, there is no per-OS release isolation (you cannot pin
  Alpine to an older shared version without pinning everyone), and Windows
  (PowerShell, not a Unix tree) does not fit the layout.

### The model in use (recommended)

A **three-layer, multi-repo model with Core vendored by `git subtree`**:

| Layer | Lives in | Owns |
| --- | --- | --- |
| **Core** | `dotfiles-core`, vendored into each OS repo's `core/` | zsh modules, tmux, nvim, git, starship — identical everywhere |
| **OS-native** | one repo per OS | package manager, clipboard, paths, bootstrap |
| **Role** | `dotfiles-Kali` (offensive), `dotfiles-Defense` (blue) | engagement / detection tooling layered on an OS |

Each OS repo therefore carries **only** vendored Core plus its own thin OS layer
— not the other seven OSes' files. The zsh **load order is the contract**
(`tools → ui → options → history → aliases → git → functions → fzf → bindings →
plugins → op → maint → update → os → local`); OS and Role repos extend it by
appending stages (`… os offensive local` on Kali, `… os defense local` on
Defense), never by editing Core.

Why `git subtree` rather than a submodule: the vendored `core/` is present
offline with no second clone step, its history is squashed into the OS repo, and
the "edit upstream, then `make sync`" discipline is enforced by the audit and
`fleet-drift.sh`. The cost — never hand-edit `core/` in an OS repo — is the same
rule the whole system already lives by.

## 4. Safe deployment: testing Arch without breaking Alpine or macOS

This is the core safety question, and the architecture answers most of it *by
construction* before any tagging discipline is added.

### A change "meant for Arch" is one of two things

1. **OS-specific** (a `pacman`/AUR tweak, an Arch path). It belongs in
   `dotfiles-Arch`'s own `os/` layer and goes in **no** Core release. Alpine,
   macOS, and the rest literally never see it — they vendor Core, not each
   other's OS layers. This is total isolation for free; it is also the "is it
   Core?" test doing its job. **If a change is not identical on every machine,
   it is not Core, and it cannot reach another OS.**
2. **Actually Core** (identical everywhere). Then it is *supposed* to reach all
   eight — so the safety you want is not isolation but a **staged rollout** with
   a rollback per OS, below.

### Why a host cannot be broken behind your back

A Core change reaches a live host only after **three independent opt-in gates**,
in order. Core never pushes to a machine:

1. It is merged and **tagged** in `dotfiles-core` (and `release.sh` + the
   `sync-core.sh` gate both require a green audit first).
2. The target OS repo **pulls** it (`git subtree pull` / `make sync`) and
   commits the new `core.lock`.
3. The host **re-bootstraps or re-sources** to pick up the new files.

Skip any one and the host stays on what it had. An Alpine container that never
runs step 2 is unaffected by anything you tag, forever.

### Pin OS repos to a tag, not to `main`

Today `core.lock` records a `core_sha` on `main` — meaning "whatever `main`
happened to be at sync time." Tighten this so each OS repo vendors a **named
tag**:

```sh
# in an OS repo, adopt a specific Core release rather than main's tip
git subtree pull --prefix=core <core-remote> v1.3.0 --squash
```

Now "what Alpine runs" is a frozen, named version, and rolling one OS back is
just pulling the previous tag there — it touches no other repo. Until the
tooling stamps a `core_tag` automatically, record the tag in the sync commit
message.

### The staged rollout for a Core release

1. **Tag** `vX.Y.Z` in Core. The audit is green (enforced by `release.sh` and
   the fan-out gate).
2. **Canary** into one low-risk repo first — `dotfiles-MacBook` (the reference
   implementation) or a throwaway Alpine/Arch container. Bootstrap it and smoke
   test: shell starts, load order intact, no broken bindings.
3. **Bake** on the canary for a few days. Real use surfaces what CI cannot.
4. **Fan out** with `make sync` to the rest; `make fleet-drift` confirms every
   repo converged on the new tag.
5. **Roll back per OS** if needed: re-pull the previous tag in just the affected
   repo. Alpine rolling back to `v1.2.0` does not touch macOS on `v1.3.0` — the
   repos are independent consumers.

### What CI must prove before a tag

The pre-tag gate is already most of the way there and should be treated as
release-blocking:

- `ci.yml` runs the full audit on push and PR, including the **macOS bash 3.2**
  leg — so a Bashism that would break the Mac is caught before a tag.
- `bootstrap-test.yml` exercises the bootstrap path.
- The behavioral suite (`test-core.sh`) checks load order and function units
  cross-shell.

The one gap worth closing: a **per-OS container smoke** (Alpine `musl`/`doas`,
Arch rolling) in CI as an explicit pre-tag step, so "works on Fedora" never
silently means "assumed to work on Alpine."

## 5. Checklists

### Cut a Core release

```sh
make release VERSION=X.Y.Z   # bumps core.version, promotes CHANGELOG, runs the audit
git diff                     # review the two-file change
git add core.version CHANGELOG.md && git commit -m "release vX.Y.Z"
git tag -a vX.Y.Z -m vX.Y.Z  # the tag this fleet has never had — start here
git push && git push --tags
make release-notes           # optional: draft the GitHub Release body (git-cliff)
```

### Adopt tagging (one-time)

The repo has the release machinery but **no tags yet**. Bless the current tip as
the baseline so every future release has a `git describe`-able predecessor:

```sh
git tag -a v1.2.0 -m v1.2.0   # match the existing core.version stamp
git push --tags
```

### Fan out and verify

```sh
make sync          # vendor the tagged Core into every OS repo (green audit required)
make fleet-drift   # confirm no repo lags the new tag
```

### Roll one OS back

```sh
# in the affected OS repo only
git subtree pull --prefix=core <core-remote> v<previous> --squash
```

## 6. Gaps worth automating next

- **Stamp the tag in `core.lock`.** Add a `core_tag` field so `fleet-drift.sh`
  reports drift against named releases, not just SHAs.
- **Per-OS container smoke in CI** (Alpine musl, Arch rolling) as a pre-tag
  gate, closing the "passed on Fedora, assumed on Alpine" gap.
- **A `make tag` step** that runs the commit + tag + push after `release.sh`,
  so cutting a release is one command end to end rather than a printed recipe.
