# Cross-shell parity contract

The fleet drives two interactive shells: **zsh** (Core, vendored into every Unix
repo) and **PowerShell** (the `dotfiles-Windows` host layer, reimplemented natively
— it does *not* vendor Core). A cross-platform operator moving between WSL-zsh and
Windows-pwsh in the same day should find the same muscle memory on both.

This file is the **source of truth** for what "the same" means. Each capability is
one of:

- **`aligned`** — same behaviour + same trigger on both shells. Changing one side
  without the other is a regression; keep them in step.
- **`deliberate`** — intentionally different because the platforms differ (a tool
  is Windows-only, or the host has no tmux). Documented so it's a *decision*, not
  drift.
- **`gap`** — a capability one shell has and the other could, but doesn't yet.
  An open item, not a promise.

> Sources: zsh in `zsh/{aliases,git,fzf,bindings,tools}.zsh`; pwsh in
> `dotfiles-Windows/powershell/core/{00-aliases,10-tools,20-functions}.ps1`.

## Prompt & tool init

| Capability | zsh | pwsh | Status |
| --- | --- | --- | --- |
| Prompt | starship (`starship.toml`) | starship (same `starship.toml`) | `aligned` |
| Theme | tokyonight-storm | tokyonight-storm | `aligned` |
| Smart `cd` | zoxide (`cd`→`z`, `cdi`/`zi`) | zoxide (`cd` hijacked, `zi`) | `aligned` |
| History sync | atuin | atuin | `aligned` (engine) |
| Completion | carapace + fzf-tab | carapace + PSFzf + CompletionPredictor | `deliberate` |

## Aliases

The alias surface is broadly `aligned`: `ll`/`la`, `cat`→bat, `grep`→rg, `http`→xh,
`dns`→doggo, `du`→dust, `watch`→viddy, `lg`→lazygit, and the git shorthands
(`g`, `gst`/`gss`, `ga`/`gaa`, `gc`/`gcm`, `gco`, `gd`, `gl` pull / `gp` push,
`glog`) resolve to the same intent on both shells. Per-shell extras are noted as
gaps below.

## Keybindings

| Capability | zsh | pwsh | Status |
| --- | --- | --- | --- |
| History search | `Ctrl+R` (fzf widget) | `Ctrl+R` (atuin, else PSFzf) | `aligned` (Ctrl+R = history) |
| FZF palette | tokyonight-storm `--color` | tokyonight-storm `--color` | `aligned` |
| FZF source cmd | `fd` (`FZF_DEFAULT_COMMAND`) | `fd` (`FZF_DEFAULT_COMMAND`) | `aligned` |
| File picker | `Ctrl+F` (`_fzf_file_no_hidden`) | `Ctrl+T` (PSFzf) | **`gap`** — different key |
| atuin TUI | `Ctrl+E` (`_atuin_search_widget`) | folded into `Ctrl+R` | **`gap`** — no distinct key on pwsh |
| Dir jump | `Alt+Z` (zoxide) / `Alt+C` (fzf) | `Alt+C` (PSFzf cd) | `deliberate` (`Alt+C` both; `Alt+Z` zsh extra) |
| Session picker | `Ctrl+G` (sesh) | — | `deliberate` (no tmux sessionizer on the host) |
| Cheatsheet | `core-help` / `cheat` | `Ctrl+G` (navi widget) | **collision** — same key, different tool |
| Autosuggest toggle | `Ctrl+\` | PSReadLine predictive (always on) | `deliberate` |
| Word nav | `Ctrl+←/→` | `Ctrl+←/→` (PSReadLine) | `aligned` |

## Functions

| Capability | zsh | pwsh | Status |
| --- | --- | --- | --- |
| `extract`, `mkbak`, `serve`, `fif`, `fbr` | yes | yes | `aligned` |
| Fuzzy git stage/restore (`gaf`/`grf`/`grsf`) | yes | — | **`gap`** |
| `cheat` (cht.sh) | — | yes | `gap` (reverse) |

## Open decisions

The **collision** and **gap** rows above are the ones that change daily muscle
memory, so they are decisions for the operator, not silent edits:

1. **`Ctrl+G`** — zsh opens a tmux session picker (sesh); pwsh opens a navi
   cheatsheet. Same key, different action. Options: rebind one, or accept the
   split (the host genuinely has no tmux sessionizer).
2. **File picker key** — unify on `Ctrl+F` or `Ctrl+T` across both.
3. **atuin key** — give pwsh a distinct `Ctrl+E` (matching zsh) and leave `Ctrl+R`
   to the fzf-style widget on both, or keep pwsh's fold-into-`Ctrl+R`.
4. **Port to pwsh** — `gaf`/`grf`/`grsf` fuzzy git staging, `Alt+Z` zoxide jump.

When a decision is made, move the row to `aligned` (or `deliberate` with the
rationale) and implement it on both sides in the same change.

## Enforcement

`scripts/parity-check.sh` (`make parity-check`) mechanises the `aligned` rows: it
asserts a distinctive needle for each is present in BOTH a zsh source and the pwsh
source, and exits non-zero when one side drifts. It reads pwsh from a sibling
`dotfiles-Windows` checkout (skipped with a notice if absent, unless `--strict`),
exactly like `scripts/fleet-drift.sh`. The weekly `.github/workflows/parity-check.yml`
clones `dotfiles-Windows` and runs it `--strict`, failing red on drift.

When a row here moves to `aligned`, add a matching check to `parity-check.sh` in the
same change — the check is the enforcement. The keybinding rows under **Open
decisions** are deliberately *not* enforced yet; they join the checker as each
decision is made and implemented on both shells.
