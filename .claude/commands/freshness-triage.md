---
description: Review open dependency-bump PRs against upstream changelogs
argument-hint: "[PR number, optional — defaults to all open bot PRs]"
allowed-tools: Task, Read, Grep, Glob, WebSearch, WebFetch, Bash(./scripts/update-plugins.sh --check), Bash(./scripts/update-nvim-plugins.sh --check), Bash(git log:*), Bash(git diff:*)
---

# /freshness-triage

Decide whether the automated dependency bumps are **safe to merge** — the judgment
half of the `freshness.yml` bot, which can roll pins forward and open a PR but
cannot read an upstream changelog for a breaking change.

Target for this run: **$ARGUMENTS** (empty = all open automation PRs).

## What the bots produce

- **`freshness.yml`** (weekly) — rolls the pinned zsh-plugin SHAs in
  `zsh/plugins.zsh` and refreshes `nvim/lazy-lock.json`, opening PRs on
  `automation/freshness-zsh-plugins` and `automation/freshness-nvim-plugins`.
- **`dependabot.yml`** (weekly) — bumps GitHub Actions in `.github/workflows/`.

The `--check` modes are the source of truth for "is it behind":

```bash
./scripts/update-plugins.sh --check
./scripts/update-nvim-plugins.sh --check
```

## What to do per PR

1. **Identify what moved** — read the diff: which plugin/action, from which pin to
   which.
2. **Read the upstream changelog/release notes** between the old and new ref
   (WebFetch the project's releases/CHANGELOG). Look specifically for: breaking
   changes, removed/renamed options, new required config, and security fixes.
3. **Map impact to this repo** — does the bumped plugin's config in `zsh/`,
   `nvim/`, or the load order rely on anything the bump changes?
4. **Confirm the gate** — note whether CI is green on the PR; a bump that fails
   `make audit` is never mergeable regardless of the changelog.

## How to report

Per PR, a verdict:

- **Merge** — no breaking changes, CI green; one line on what it brings.
- **Hold** — what specifically would break and the config that needs to change
  first.
- **Security** — call out any bump that fixes a known vuln (merge priority).

Post a comment on the PR or merge only if I ask — default to reporting here.
