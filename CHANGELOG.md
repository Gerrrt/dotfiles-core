# Changelog

All notable changes to **dotfiles-core** are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Core is the single source of truth vendored into nine OS repos via
`git subtree pull --prefix=core <core-remote> main --squash` (see `scripts/sync-core.sh`).
Every entry below is therefore a change those repos receive on their next sync —
this file is the human-readable record of _what_ a sync will bring, complementing
the SHA that `scripts/sync-core.sh` now prints. To cut a release, move the
`[Unreleased]` items under a new `## [vX.Y.Z] - YYYY-MM-DD` heading and tag the
commit (`git tag -a vX.Y.Z -m vX.Y.Z`).

## [Unreleased]

## [v1.1.0] - 2026-06-19

## [v1.0.0] - 2026-06-18

### Added

- **lazygit theme** (`lazygit/config.yml`) — a tokyonight-storm theme matching
  `starship.toml`, the tmux bar, and `zsh/fzf.zsh`, so lazygit (reached via the `lg`
  alias and the `prefix + g` tmux popup) reads as one palette with the rest of the
  stack. Bootstrap symlinks it to `~/.config/lazygit/config.yml`.
- **`genpw [length]`** — portable random-password generator (`zsh/functions.zsh`):
  prefers `openssl`, falls back to `/dev/urandom` so it works on a bare rescue shell.
  Ships with its completion (`zsh/completions/_genpw`) and a `core-help` entry.
- **fzf tokyonight palette** — `FZF_DEFAULT_OPTS` (`zsh/fzf.zsh`) now sets an explicit
  tokyonight-storm `--color` set instead of inheriting the terminal palette, keeping
  fzf on-theme even over SSH into an unthemed box.
- Audit **`--strict`** now fails only on gates skipped because their TOOL is absent (an
  out-of-scope skip stays intentional), so CI runs it on the Linux leg — closing the last
  "green because a linter silently failed to install" gap. CI also installs `python3-yaml`
  so the YAML-parse gate is honest under `--strict`.
- **Core⇄OS boundary** audit gate: portable `zsh/*.zsh` modules may carry no OS-absolute
  paths (`/opt/homebrew`, `~/Library`, …), mechanically enforcing the README's "if it
  changes with the OS it isn't Core" rule. `zsh/maint.zsh` (the OS-switched scheduler
  surface) is the documented exception.
- **`core.version` ↔ `CHANGELOG`** coherence gate: a prerelease stamp must keep an
  `[Unreleased]` section open; a release stamp must have a matching `## [vX.Y.Z]` heading.
- Behavioral coverage for `git.zsh` (`git_main_branch`/`git_current_branch` trunk +
  detached-HEAD resolution) and for `_pkgup_count`/`_pkgup_list` parsing on
  apk/dnf/zypper/pacman — previously only apt was exercised.
- `core-help` now lists the most-used **git aliases** (the OMZ-style set in `git.zsh`),
  so they are discoverable from the cheat sheet.
- `core.version` — a human-readable SemVer stamp vendored into every OS repo, plus a
  `core-version` verb that reads it, so you can tell WHICH Core a given OS repo carries
  from inside it (the subtree squash records the commit; this records the version).
  `scripts/sync-core.sh` prints it on fan-out and the audit asserts it is well-formed.
- `core-doctor` — the shell counterpart to nvim's `:checkhealth gerrrt`: a scannable
  report of which modern-CLI tools Core detected on this box and which integrations are
  live, including the RESOLVED binary names (`fd`/`fdfind`, `bat`/`batcat`) and the
  detected package manager. Read-only.
- `up -n`/`--dry-run` — list the packages that WOULD upgrade and exit, touching nothing
  (the non-destructive inspect the count-only nudge didn't offer).
- `make audit-changed` (`audit-core.sh --changed`) — scope the audit to what your local
  git diff touches, via the SAME `scripts/ci-classify.sh` CI uses; fails safe to the
  full run when the diff can't be resolved.
- First-party completions for `fif`, `fbr`, `core-version`, and `core-doctor`, and a
  `core.version`/`up --dry-run`-aware `_up`; the completion-parity test now covers them.
- `.shellcheckrc` — repo-wide ShellCheck config (`external-sources`, `source-path`,
  `shell=bash`) so author-time, CI, and editor lint identically.
- `zsh/ui.zsh` — shared terminal-UX primitives (`_core_err`/`_core_warn`/`_core_ok`/
  `_core_hint`/`_core_usage`/`_core_confirm`/`_core_spin`), gum-aware with a plain
  fallback on every helper. Loads right after `tools` in the canonical chain and is
  adopted across `functions.zsh`, `op.zsh`, `update.zsh`, and `plugins.zsh`, replacing
  ad-hoc `echo "Usage: …"` lines with one consistent voice (colour only on a TTY,
  `NO_COLOR` honoured, diagnostics to stderr).
- `core-help` (alias `cheat`): a grouped, column-aligned cheat sheet of Core's
  functions, keybindings, and maintenance verbs — the shell counterpart to which-key.
  Plus a once-per-machine first-run hint pointing at it (`CORE_WELCOME=0` to silence).
- First-party zsh completions (`zsh/completions/`) for Core's own verbs — `up`,
  `extract` (archive files only), `mkcd`, `mkbak`, `maint-log`, `openv` — fpath-added
  by `options.zsh` (symlink-safe; no bootstrap symlink needed). The audit now `zsh -n`s
  them alongside `zsh/*.zsh`.
- `scripts/lib/common.sh` — one definition of the colour palette + `pass`/`skip`/`fail`/
  `hdr`/`have` shared by all five gate scripts (the block had been copy-pasted ×5). A
  sourced lib, so — like `zsh/*.zsh` — it stays mode 100644; the audit's exec-bit
  section gained a `scripts/lib/*.sh` arm to assert exactly that.
- `scripts/tool-versions.env` — single source for the pinned dev-tool versions, read by
  CI (loaded into `$GITHUB_ENV`), `make setup`, and the audit. `scripts/setup.sh` +
  `make setup`: a one-command dev bootstrap (pre-commit hooks + version doctor + audit).
- `actionlint` gate on the workflows: an audit section (graceful skip when absent) plus
  a pinned CI install — the workflow YAML is now validated, not just parsed.
- Audit version-consistency section: the `.pre-commit-config.yaml` hook revs are gated
  to equal `scripts/tool-versions.env`, so a one-sided pin bump fails the audit.
- Hermetic behavioral tests for `bin/clip` / `bin/clip-paste` (the highest-fan-out
  runtime artifact — used by zsh, tmux, and nvim): a new section in
  `scripts/test-core.sh` drives the WSL→macOS→Wayland→X11 detection ladder against a
  fake `PATH`, asserting the right backend is chosen. Runs even where zsh is absent.
- Headless Neovim config-load smoke test in `scripts/test-core.sh`: loads the authored
  config layer and every plugin spec offline (no install), catching luacheck-clean Lua
  that is nonetheless a broken config. CI ships a pinned `nvim` (`NVIM_VERSION`) so it
  runs on both userlands instead of skipping.
- Alpine (musl/busybox) CI leg, run via a bind-mounted container, finally exercising
  the busybox-coreutils compatibility the scripts have always claimed.
- `scripts/update-plugins.sh` + `make update-plugins`: deliberately roll the pinned
  zsh-plugin SHAs to upstream HEAD — the runtime-plugin mirror of `make update-hooks`.
- Markdown lint gate: `.markdownlint.jsonc` rule config, a `markdownlint` section in
  `scripts/audit-core.sh` (graceful skip when absent), a `markdownlint-cli2` pre-commit
  hook, and a pinned CI install step — so the docs (the deliverable on a public
  showcase repo) are gated like everything else.
- `scripts/bench-core.sh` gained an optional `CORE_BENCH_BUDGET_MS` budget gate (fails
  when the canonical-chain startup mean exceeds the budget), plus a non-blocking CI
  `bench` job that reports the number on every push.
- `SECURITY.md` and `.github/ISSUE_TEMPLATE/` (bug + feature + config) round out the
  GitHub community profile; `CONTRIBUTING.md` documents a Conventional Commits
  convention.
- Broader behavioral coverage in `scripts/test-core.sh`: `mkbak` byte-identity,
  `extract` unknown-format rejection, and `extract` round-trips for `.tar.gz`/`.gz`
  (the latter skip gracefully when `tar`/`gzip` are absent).
- CI runs the audit on a `[ubuntu-latest, macos-latest]` matrix, gating the macOS
  (bash 3.2 / BSD userland) target — `dotfiles-MacBook` — alongside Linux.
- `scripts/audit-core.sh` and the pre-commit config parse-check every tracked TOML and
  YAML file, catching malformed `starship.toml` / `mise/config.toml` / workflow
  YAML that is valid text but dead at runtime for every consumer.
- This `CHANGELOG.md`.
- `scripts/sync-core.sh` reports the exact dotfiles-core revision (short SHA) each OS
  repo receives, so a sync is traceable.
- `scripts/bench-core.sh` + `make bench`: a hermetic hyperfine benchmark of the
  canonical Core load chain, so startup-perf regressions (the thing tools.zsh's
  caching and plugins.zsh's deferral exist to prevent) are measurable, not silent.
- A `command_not_found_handler` (zsh): a mistyped command now gets a Core-voice miss
  that suggests the nearest Core verb on a near typo (`extarct` → `extract`, via a
  small built-in Levenshtein) or, failing that, an install line for this box's detected
  package manager — instead of zsh's terse default. Interactive-only; `CORE_CNF_ENABLED=0`
  opts out.
- `make doctor` (`scripts/setup.sh --doctor`): the read-only half of `make setup` —
  reports each dev tool against its pin with no install and no audit, for quick "is my
  toolchain aligned with CI?" triage.
- `core-help <word>` filters the cheat sheet to matching rows (and reports a no-match
  cleanly), so jumping to one verb beats scanning the whole sheet.
- `serve` renders the reachable URL as a terminal QR code when `qrencode` is present
  (scan-to-open from a phone) — graceful skip when it isn't.
- `scripts/audit-core.sh --strict`: treat any SKIP as a failure (a gate whose tool was
  absent did not actually run), for release/CI verification where every gate must execute.
- `ui.zsh` primitives: `_core_errbox` (multi-line what/why/fix error blocks),
  `_core_suggest`/`_core_lev` (did-you-mean), reused across the runtime helpers.

### Changed

- The `command_not_found_handler` now also weighs this shell's **aliases** when proposing
  a "did you mean?", so a near miss like `gts`→`gst` is caught, not just the Core verbs.
- The markdown gate resolves `markdownlint-cli2` via PATH → `npx --no-install` →
  `node_modules`, so an off-PATH global install runs instead of skipping (the most-skipped
  gate in remote sessions).
- `_cache_eval` gained `--salt`; the `atuin`/`carapace` inits fold `ATUIN_NOBIND`/
  `CARAPACE_BRIDGES` into the cache filename, so flipping that env busts the cache
  instead of serving a stale init.
- Higher-friction failures now use the structured `_core_errbox` (headline + why/fix):
  `up` with no package manager, and `serve` without `python3`.
- `scripts/setup.sh` provisions `luacheck` via `luarocks` (no clean mise source) and
  emits precise, actionable install hints — closing the last manual onboarding gap.
- Defensive confirms on impactful interactive actions: `please` now previews the exact
  `sudo …` line and confirms before eval'ing it as root (and refuses with no previous
  command); `up` pre-confirms `Apply updates with <mgr>?` before touching the system
  (skipped by `-y`); `serve` warns plainly that it binds `0.0.0.0` and exposes the CWD.
- First-run plugin install shows a spinner on the network-bound `git fetch`/`clone`
  (gum spin when present, a hand-rolled braille spinner otherwise), guarded so an OS
  loader that hasn't adopted `ui.zsh` yet still installs plainly.
- CI is now incremental: a `changes` job classifies the diff and gates the narrow,
  expensive legs — `nvim`+`luacheck` installs run only when `nvim/` changed, and the
  Alpine and bench jobs only when the shell layer changed. SAFE DEFAULT: an unresolved
  diff base or any infra change runs everything, so detection can never hide a check.
- The startup-perf `bench` CI job is now an enforced regression gate
  (`CORE_BENCH_BUDGET_MS=120` over 50 warmed runs), not a report-only, continue-on-error
  step — a gross startup regression now fails the build instead of shipping silently.
- The pinned linter versions moved out of `ci.yml`'s `env:` block into
  `scripts/tool-versions.env`; CI loads them via a "Load pinned tool versions" step.
- Split `bin/` into shipped vs. tooling: `bin/` now holds only what is vendored into
  the OS repos (`clip`, `clip-paste`); the gate scripts moved to `scripts/`
  (`audit-core.sh`, `test-core.sh`, `bench-core.sh`, `sync-core.sh`,
  `update-plugins.sh`). The audit allowlists `scripts/` wholesale, so a new dev tool
  is covered the moment it lands. No consumer impact — those scripts were never in
  the manifest, so they were never vendored.
- `scripts/audit-core.sh` no longer uses the bash-4-only `mapfile`, so the gate itself
  runs on macOS's stock bash 3.2.
- The audit summary now NAMES the checks that skipped (tool absent) and labels such a
  run PARTIAL rather than hiding the gap behind a bare count — several skipped gates
  (markdownlint, actionlint, gitleaks, luacheck, nvim) are CI-enforced, so a clean local
  box can still differ from the gate.
- `core-doctor` now turns its `✗` tools into a copy-pasteable install line for this box's
  package manager, instead of leaving the reader to look each one up.
- Spinner (`_core_spin`) shows elapsed time and ends with a still `✓`/`✗` result frame, so
  a long step reads as progress and finishes with a legible outcome; `extract` routes the
  quiet unpack formats through it. Unknown-format `extract` errors print a what/why/fix block.
- `serve`/`up` suggest the nearest valid flag on an unknown option (did-you-mean).
- De-duplicated the gate scripts: the `_set_scope` area parser, the hermetic plugin-seed
  list, and the `ci-classify.sh` output reader now live once in `scripts/lib/common.sh`
  (consumed by `audit-core.sh`, `test-core.sh`, `bench-core.sh`) — they had drift-prone
  copies. `op.zsh` verbs gained the `emulate -L zsh` every other Core verb uses.

### Security

- Pinned the seven runtime zsh plugins to commit SHAs (`ZPLUGIN_PINS` in
  `zsh/plugins.zsh`) — the last unpinned link in a toolchain that already pins CI
  linters, pre-commit hooks, and GitHub Actions. An unpinned `master` clone fanned an
  upstream breaking change — or a compromised tag — out to all nine machines on the
  next install; installs now fetch exactly the pinned commit.

### Fixed

- `fbr`'s fzf preview used `{1}`, which on the current-branch row (`* main`) is the
  literal `*` — so the preview ran `git log *` and broke. It now lists clean branch
  names (`--format='%(refname:short)'`, `*/HEAD` dropped) and previews `{}`; a remote-only
  pick strips `origin/` on checkout to create the matching local tracking branch.
- `mkbak` could prompt or clobber: `cp -i` (from `aliases.zsh`, parsed first) bled into
  it, so a same-second second backup stopped for a y/n. It now picks the next free `.bak`
  suffix and copies via `command cp`, staying collision-safe and non-interactive.
- `_core_confirm`'s gum path defaulted to **Yes** while the `[y/N]` fallback defaulted to
  No — so the same destructive prompt (`please`/`up`/extract-overwrite) was one-Enter-to
  confirm under gum. It now passes `gum confirm --default=false`, a consistent safe default.
- The `_core-help` completion claimed "takes no arguments", but `core-help` accepts a
  `[filter]`; it now completes that filter with the verbs/sections the cheat sheet knows.
- `serve` now pre-checks the port is bindable (with `SO_REUSEADDR`, as `http.server`
  does) and fails in Core's voice instead of letting a taken port surface a Python traceback.
- `diff` was unconditionally aliased to `diff --color=auto`, which BSD/macOS `diff` (the
  dotfiles-MacBook target) does not support — every `diff` invocation would error there.
  The alias is now applied only after a feature-probe confirms this box's `diff` accepts it.
- fzf / fzf-tab previews hardcoded `bat`/`eza`, so every preview pane printed
  "command not found" on Debian/Ubuntu (bat ships as `batcat`) and on any box without
  eza. Previews now resolve `$BAT_BIN` with a `cat`/`ls` fallback, and a new audit
  section (`fzf preview binary resolution`) locks it so the regression can't recur.
- `fif`, `fbr`, and the Alt-Z zoxide-jump widget assumed `fzf`/`rg`/`git`/`zoxide`
  were present; they now degrade in Core's voice (`_core_err`/`_core_hint`) like `fcd`,
  instead of a raw "command not found".
- Removed leaked `</content>`/`</invoke>` template artifacts from the end of this
  changelog — the exact bug class the new markdown gate now catches.
- Restored non-executable mode (`100644`) on the twelve `zsh/*.zsh` modules. They
  are sourced, not executed, and had regressed to `100755`, failing the audit's
  exec-bit invariant — the exact bug class the audit exists to catch, fanning out
  to all nine OS repos.
- Registered `CODEOWNERS`, `dependabot.yml`, and `pull_request_template.md` in the
  audit's `META_ALLOWLIST` so the manifest reverse-drift scan accounts for them.
