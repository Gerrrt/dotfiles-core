# dotfiles-Defense — plan & reference skeleton

A forward-looking architecture note plus a **complete, ready-to-instantiate
skeleton** for a future `dotfiles-Defense` repo — the defensive (blue) **Role**
layer that mirrors `dotfiles-Kali`. It lives here, in the source-of-truth repo,
so the decision and the skeleton are durable and reviewable **before** a real
repo exists. Nothing here is wired into Core or vendored out; it is repo-meta
planning, allowlisted in `scripts/audit-core.sh`.

When the trigger below is met, this doc is the 20-minute stand-up: create the
directory, drop in the files reproduced verbatim in [The files](#the-files),
`git init`, vendor Core, run `bootstrap.sh`.

## The decision — red and blue are both Roles

The three-layer model (Core → OS-native → Role) already has the slot. Offensive
(`dotfiles-Kali`) is a Role. **Defensive is just another Role** on the same Core.
So this was never an architecture gap — only a one-repo-or-two call, which is a
maturity/volume question, not a philosophy one.

The two sides stay **split, not merged**:

- **Attack-paired detections stay in Kali.** Detections written from the
  attacker's chair — "here's the telemetry I trip" — live in Kali's
  `PURPLE-TEAM.md`. That is purple, and it belongs next to the attacks it mirrors.
- **Defender-authored capability gets its own repo.** Sysmon baselines, Sigma
  rules, Zeek/Suricata tuning, SIEM saved-searches, and the hunt/triage workflow
  are a different job from a different seat — `dotfiles-Defense`.

## The trigger — when to actually stand it up

Create the live repo the moment blue content stops being *attack-paired notes*
and becomes *defender-authored capability* that stands on its own — concretely,
when you start carrying any of:

- Sysmon config XML (a SwiftOnSecurity / Olaf-Hartong-modular baseline)
- Sigma rules or compiled SIEM content (`props.conf`/`transforms.conf`, dashboards)
- Zeek scripts / Suricata rule tuning
- A detection-lab stack (a monitored host + log pipeline) that does not reference
  the offensive side

Until then, the purple content stays unified in Kali and this doc just waits.

## Identity & layer table

`dotfiles-Defense` is **distro-agnostic**: host tools come from whatever
OS-native layer you already run, and the heavy stack (Zeek, Suricata, Wazuh,
Elastic/Splunk, Velociraptor) runs in Docker. No Security Onion, no blue distro —
SO is a SOC sensor appliance, not a dotfiles target.

| Layer | Source | What it carries |
| --- | --- | --- |
| Core | vendored from `dotfiles-core` under `core/` | zsh, tmux, nvim, git, starship |
| OS-native | your existing OS repo (Fedora/Arch/…) | package manager, clipboard, paths |
| Defense (role) | `defense/` + `detections/` + `docker/` | hunt/triage tooling, detection content, the lab |

It adds one zsh loader stage, mirroring Kali's `offensive` stage:

```text
tools → … → op → maint → update → os → defense → local
```

## File tree

```text
dotfiles-Defense/
├── README.md
├── CLAUDE.md
├── DEFENSE-METHODOLOGY.md
├── bootstrap.sh                      # +x
├── .gitignore
├── defense/
│   ├── defense.zsh                   # the role layer (HAVE_*-guarded)
│   └── templates/
│       ├── case.md
│       └── hunt.md
├── detections/
│   ├── README.md
│   ├── sigma/        (.gitkeep)
│   ├── sysmon/       (.gitkeep)
│   ├── network/      (.gitkeep)
│   └── siem/         (.gitkeep)
├── docker/
│   ├── README.md
│   └── detection-lab.compose.yml
└── install/
    └── README.md
```

## Stand-up steps

```bash
mkdir -p ~/dotfiles-Defense && cd ~/dotfiles-Defense
# recreate the files from "The files" below (or copy a saved scaffold), then:
mkdir -p defense/templates detections/{sigma,sysmon,network,siem} docker install
touch detections/{sigma,sysmon,network,siem}/.gitkeep
chmod +x bootstrap.sh
git init -b main
git subtree add --prefix=core <dotfiles-core remote> main --squash   # vendor Core
./bootstrap.sh                                                        # wire it up
```

## The files

Each file below is reproduced verbatim from the validated scaffold: `bootstrap.sh`
is **shellcheck-clean** (+ `bash -n`), `defense.zsh` passes `zsh -n` and loads its
helpers under an interactive shell, and the compose YAML parses. The stand-up was
exercised end-to-end in a sandbox (`bootstrap.sh --links-only` wires Core + the
defense stage). Markdown files are shown in four-backtick fences so their own code
blocks render intact.

### README.md

````markdown
# dotfiles-Defense

The **defensive (blue) role** of the dotfiles system — the mirror image of
`dotfiles-Kali`. Where Kali carries the offensive engagement layer, this repo
carries the **detection-engineering & investigation** layer: the tooling,
configs, and workspace workflow for hunting, triage, and standing up a small
detection lab.

Like Kali, it stacks **three** layers: Core (vendored) → OS-native (your
existing OS repo) → Defense (role). The defense layer is unique to this repo:
hunt/triage tooling, version-controlled detection content, and a Dockerized lab.

## The one rule that matters

**This is a public repo. Case, evidence, and log data NEVER live in it.** All
investigation data lives under `~/cases/` (outside the repo), exactly like Kali
keeps engagements in `~/engagements/`. The paranoid `.gitignore` is a backstop,
not the primary control. `mkcase` scaffolds a case outside the repo by design.

## Distro-agnostic + Docker (no blue-team distro required)

You do not need Security Onion or a dedicated blue distro — SO is a SOC sensor
appliance, not a dotfiles target. The blue stack is overwhelmingly containers, so
this repo assumes no specific OS: host tools come from your OS-native layer, and
the heavy stack comes up via `docker/` (`siemup` / `siemdown`).

## Loader integration

Adds one stage to the zsh loader, just before local overrides:
`tools → … → os → defense → local`. `defense/defense.zsh` →
`~/.config/zsh/defense.zsh` holds workflow helpers only (`mkcase`, `gocase`,
`note`, `siemup`/`siemdown`), all `HAVE_*`-guarded.

## What the layer ships

- `defense/defense.zsh` — role-stage ergonomics + case workflow
- `defense/templates/` — `case.md` / `hunt.md` seeds
- `detections/` — version-controlled detection content (Sigma, Sysmon, network, SIEM)
- `docker/` — the detection-lab compose stack(s)
- `DEFENSE-METHODOLOGY.md` — the ATT&CK → data-source → detection map
- `install/` — host-tool notes (distro-agnostic)

The attack-paired mirror lives in Kali's `PURPLE-TEAM.md`; the two cross-link.
````

### CLAUDE.md

````markdown
# CLAUDE.md — dotfiles-Defense

Project memory for Claude Code. For the shared Core rules see `core/README.md`
and `core/CONTRIBUTING.md`.

## What this repo is

`dotfiles-Defense` is the **defensive (blue) Role layer** of the dotfiles system
(Core → OS-native → Role). It is the mirror of `dotfiles-Kali`: detection
engineering & investigation instead of offense — hunt/triage tooling,
version-controlled detection content, and a Dockerized detection lab. It is
**distro-agnostic**: host tools come from the OS-native layer, heavy stack in
containers.

## The rule that bites

- `core/` is a vendored subtree of dotfiles-core — never edit it here; fix
  upstream then sync.
- The loader adds a **`defense` stage** (`… os defense local`) — keep blue config
  there, not in `core/`.
- **Case/evidence data NEVER lives in the repo.** It lives in `~/cases/`; the
  `.gitignore` is only a backstop. `mkcase` scaffolds outside the repo.
- **Red vs blue is a split, not a merge.** Attacker-authored detections stay in
  Kali's `PURPLE-TEAM.md`; defender-authored capability lives here. Cross-link.

## Where things are

- `defense/defense.zsh` — role layer: `HAVE_*` detection, `mkcase`/`gocase`/`note`, `siemup`/`siemdown`
- `defense/templates/` — `case.md` / `hunt.md`
- `detections/` — `sigma/`, `sysmon/`, `network/`, `siem/`
- `docker/` — the detection-lab compose stack(s)
- `DEFENSE-METHODOLOGY.md` — ATT&CK → data-source → detection map
- `bootstrap.sh` — symlinks Core + defense, writes the loader, checks docker
- `core/` — vendored Core (read-only here)
````

### DEFENSE-METHODOLOGY.md

````markdown
# Defense Methodology — the detection map behind the tool layer

The "why" for `defense/defense.zsh`, `detections/`, and `docker/`: how the blue
tooling lines up against MITRE ATT&CK from the defender's seat. Mirror of Kali's
`OFFENSIVE-METHODOLOGY.md` — same ATT&CK through-line, opposite chair.

> The validation half lives across the fence: Kali's `PURPLE-TEAM.md` pairs each
> attack with the detection it trips. Detection engineering here + attack-paired
> detections there = the full purple loop.

## The philosophy

- **Detect the invariant, not the IOC.** Climb the Pyramid of Pain — spend
  detection budget on behaviors the technique cannot avoid (Kerberoast RC4
  downgrade, DCSync replication right, relay host-mismatch), not brittle IOCs.
- **A detection isn't real until it's fired on purpose.** Write the rule, make
  the attack happen (Atomic Red Team, Caldera, or your Kali box), watch it
  trigger. Untested detections are hypotheses.
- **No data source, no detection.** Coverage is an ingestion problem first. Map
  what you collect to what you want to catch; the gaps are the roadmap.
- **Tune for signal.** A noisy rule gets muted, and a muted rule is a blind spot.
- **Evidence is handled, not hoarded.** Case data lives outside the repo, with a
  timeline and provenance.

## ATT&CK tactic → data source → detection

| ATT&CK tactic | Primary data sources | Where detections live | Validate with (Kali) |
|---------------|----------------------|-----------------------|----------------------|
| Recon / Discovery | Zeek, 4688/4769 | network, sigma | recon / Kerberoast folds |
| Credential Access | Sysmon 10, 4625/4771 | sysmon, sigma | Responder / cracking folds |
| Lateral Movement | 4624 type 3, Zeek SMB | sigma, network | lateral-movement fold |
| Priv Esc / Persistence | Sysmon 1/13, 4720/7045 | sysmon, sigma | LOLBAS / persistence folds |
| Coercion / Relay / AD CS | 5145 pipes, 4886 SAN | siem | coercion → relay → DC fold |
| Exfil / C2 | Suricata, Zeek conn/dns | network | reverse-shell / pivot folds |

The right-hand column is the point: every row has a Kali fold that proves the
detection works.

## The detection-engineering lifecycle

1. **Hypothesis** — "an attacker doing X leaves Y" (from ATT&CK or a Kali fold).
2. **Data check** — do we collect Y? If not, that's an ingestion ticket.
3. **Author** — write it as code in `detections/` (Sigma is the source of truth).
4. **Validate (purple)** — run the technique from Kali, confirm the rule fires.
5. **Tune** — allowlist known-good, threshold the noise.
6. **Deploy + document** — record data source, ATT&CK ID, and the validation.

## OPSEC / evidence hygiene

- **Case-first.** `mkcase` writes `case.md` (scope + authorization) first.
- **Everything in `~/cases`, never in the repo.**
- **Timeline + provenance** for every artifact (`note` drops timestamped lines).
- **Containers for the heavy stuff** — the lab is ephemeral and reproducible.
````

### bootstrap.sh

```bash
#!/usr/bin/env bash
# dotfiles-Defense/bootstrap.sh
# Wire the defensive (blue) role layer onto an already-provisioned box.
# Distro-agnostic: does NOT install OS packages (your OS-native layer does that).
# Idempotent. Stacks: vendored Core + your OS-native layer + DEFENSE role.
#
#   ./bootstrap.sh                 # symlinks + loader + tool/docker checks
#   ./bootstrap.sh --links-only    # just (re)create symlinks
#   ./bootstrap.sh --no-check      # skip the host-tool / docker probe
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
LINKS_ONLY=0
DO_CHECK=1

for a in "$@"; do case "$a" in
  --links-only) LINKS_ONLY=1 ;;
  --no-check)   DO_CHECK=0 ;;
  -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
  *) echo "unknown arg: $a" >&2; exit 1 ;;
esac; done

say(){ printf '\e[36m::\e[0m %s\n' "$*"; }
ok(){  printf '\e[32m+\e[0m %s\n'  "$*"; }
warn(){ printf '\e[33m!\e[0m %s\n' "$*"; }

# ── core/ subtree present? ────────────────────────────────────────────────────
if [[ ! -d "$DOTFILES/core/zsh" ]]; then
  echo "core/ subtree missing. One time, from the repo root run:" >&2
  echo "  git subtree add --prefix=core <dotfiles-core remote> main --squash" >&2
  exit 1
fi

link(){
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" ]]; then rm -f "$dst"
  elif [[ -e "$dst" ]]; then mv "$dst" "$dst.pre-dotfiles.$(date +%s)"; fi
  ln -s "$src" "$dst"
}

# ── Host-tool / docker probe (report only — never installs) ──────────────────
check_tools(){
  say "checking host tools (install missing ones via your OS layer — see install/README.md)"
  local t missing=0
  for t in docker jq tshark zeek suricata chainsaw hayabusa sigma yara velociraptor vol log2timeline.py; do
    if command -v "$t" >/dev/null 2>&1; then ok "found: $t"
    else warn "missing: $t"; missing=$((missing+1)); fi
  done
  if command -v docker >/dev/null 2>&1; then
    if docker compose version >/dev/null 2>&1 || command -v docker-compose >/dev/null 2>&1; then
      ok "docker compose available — \`siemup\` will work"
    else warn "docker present but compose plugin missing — siemup needs it"; fi
  fi
  if (( missing == 0 )); then ok "all probed tools present"
  else warn "$missing tool(s) missing (optional — install what you need)"; fi
}

wire_links(){
  say "symlinking Core"
  for f in "$DOTFILES"/core/zsh/*.zsh; do link "$f" "$CONFIG/zsh/$(basename "$f")"; done
  [[ -f "$DOTFILES/core/tmux/tmux.conf" ]]       && link "$DOTFILES/core/tmux/tmux.conf"       "$CONFIG/tmux/tmux.conf"
  [[ -f "$DOTFILES/core/tmux/tmux.reset.conf" ]] && link "$DOTFILES/core/tmux/tmux.reset.conf" "$CONFIG/tmux/tmux.reset.conf"
  if [[ -d "$DOTFILES/core/tmux/scripts" ]]; then
    link "$DOTFILES/core/tmux/scripts" "$CONFIG/tmux/scripts"
    chmod +x "$DOTFILES"/core/tmux/scripts/*.sh 2>/dev/null || true
  fi
  [[ -f "$DOTFILES/core/starship/starship.toml" ]] && link "$DOTFILES/core/starship/starship.toml" "$CONFIG/starship.toml"
  [[ -d "$DOTFILES/core/nvim" ]]                    && link "$DOTFILES/core/nvim"                    "$CONFIG/nvim"
  [[ -f "$DOTFILES/core/git/gitconfig" ]]           && link "$DOTFILES/core/git/gitconfig"           "$HOME/.gitconfig"

  say "symlinking DEFENSE role layer"
  link "$DOTFILES/defense/defense.zsh" "$CONFIG/zsh/defense.zsh"
  [[ -d "$DOTFILES/defense/templates" ]] && link "$DOTFILES/defense/templates" "$CONFIG/defense/templates"

  if [[ ! -f "$HOME/.zshrc" ]] || ! grep -q "dotfiles-managed v2" "$HOME/.zshrc" 2>/dev/null; then
    say "writing .zshrc loader (adds the 'defense' stage)"
    [[ -f "$HOME/.zshrc" ]] && cp "$HOME/.zshrc" "$HOME/.zshrc.pre-dotfiles.$(date +%s)"
    cat > "$HOME/.zshrc" <<'ZRC'
# dotfiles-managed v2 — do not hand-edit; local tweaks go in ~/.config/zsh/local.zsh
: "${XDG_CONFIG_HOME:=$HOME/.config}"
export EDITOR=nvim VISUAL=nvim
: "${ZDOTDIR:=$XDG_CONFIG_HOME/zsh}"
export ZDOTDIR
ZSH_CFG="$ZDOTDIR"
# Core order + the 'defense' stage (unique to this repo), just before local.
_CORE_MODULES=(tools ui options history aliases git functions fzf bindings plugins op maint update os defense local)
if [[ -r "$ZSH_CFG/loader.zsh" ]]; then
  source "$ZSH_CFG/loader.zsh"
else
  print -u2 -- "zshrc: Core loader not found at $ZSH_CFG/loader.zsh — re-run the dotfiles bootstrap."
fi
unset _CORE_MODULES
ZRC
  fi
  ok "symlinks wired"
}

# --links-only skips the host-tool/docker probe too (it's the "just wire symlinks" path);
# without consulting LINKS_ONLY here, --links-only would still run the probe and the flag
# would be dead. --no-check skips it independently.
(( DO_CHECK && ! LINKS_ONLY )) && check_tools
wire_links
say "case data lives in ~/cases (outside this repo) — run \`mkcase <name>\` to start one"
ok "Defense bootstrap complete — open a new shell, or: exec zsh"
```

### .gitignore

```text
# dotfiles-Defense — paranoid .gitignore (defense-in-depth, NOT the primary control)
# Case/evidence/log data lives in ~/cases OUTSIDE this repo. This only catches
# accidents — anything that smells like investigation data, refuse to commit.

# Investigation workspaces (should never be inside the repo at all)
cases/
hunts/
evidence/
triage/

# Raw evidence & capture formats
*.pcap
*.pcapng
*.cap
*.evtx
*.evt
*.etl
*.dmp
*.mem
*.raw
*.vmem
*.aff4
*.e01
*.lime

# Logs & exported telemetry
*.log
*.jsonl
*.ndjson
*.syslog
*.winlog

# Forensic / timeline intermediates
*.plaso
*.body
*.timeline
# exported triage tables — force-add a sample if you ever need to commit one
*.csv

# Loot-adjacent: creds, tokens, keys
*.key
*.pem
*.pfx
*.kirbi
*.ccache
secrets*
creds*

# Docker / lab local state
docker/**/data/
docker/**/.env
.env

# Editor / OS noise
*.swp
.DS_Store
```

### defense/defense.zsh

```bash
# dotfiles-Defense/defense/defense.zsh
# ──────────────────────────────────────────────────────────────────────────────
# The DEFENSE (blue) layer. Sourced by the Defense .zshrc loader in its own stage:
#   tools → … → op → maint → update → os → DEFENSE → local
# (mirror of Kali's `offensive` stage — the blue role no other repo has.)
#
# Same discipline as Core/Kali: every alias/function touching an optional tool is
# GUARDED by a HAVE_* flag, so this file is inert on a box where the tool isn't
# installed instead of erroring on shell start. Distro-agnostic — tools come from
# whatever OS-native layer you run; the heavy stack runs in Docker (siemup).
#
# Investigation DATA never lives in this repo — it lives in $CASES_DIR
# (default ~/cases), which the repo .gitignore also blocks as a backstop.
# ──────────────────────────────────────────────────────────────────────────────

# Interactive shells only — scripts get raw POSIX (mirrors Core's tools.zsh).
[[ $- == *i* ]] || return 0

_have() { command -v "$1" >/dev/null 2>&1; }

# ── Detection: HAVE_* flags for the blue stack ───────────────────────────────
# Network / packet
_have zeek        && HAVE_ZEEK=1
_have suricata    && HAVE_SURICATA=1
_have tshark      && HAVE_TSHARK=1
_have ngrep       && HAVE_NGREP=1
# Windows log triage
_have chainsaw    && HAVE_CHAINSAW=1
_have hayabusa    && HAVE_HAYABUSA=1
_have evtx_dump   && HAVE_EVTXDUMP=1
# Detection content
_have sigma       && HAVE_SIGMA=1        # sigma-cli / pySigma
_have yara        && HAVE_YARA=1
# Endpoint / live response / forensics
_have velociraptor && HAVE_VELO=1
_have osqueryi    && HAVE_OSQUERY=1
_have vol         && HAVE_VOL=1          # Volatility 3
_have log2timeline.py && HAVE_PLASO=1
# Lab / containers
_have docker      && HAVE_DOCKER=1
# jq is the universal log scalpel; many helpers below assume it
_have jq          && HAVE_JQ=1

# ── Workspace root (OUTSIDE the repo — keep it that way) ─────────────────────
: "${CASES_DIR:=$HOME/cases}"
: "${DEFENSE_DIR:=${${(%):-%x}:A:h:h}}"   # repo root (this file is defense/defense.zsh)
export CASES_DIR DEFENSE_DIR

# ── Tool ergonomics (guarded) ─────────────────────────────────────────────────
[[ -n ${HAVE_CHAINSAW:-} ]] && alias hunt-evtx='chainsaw hunt --mapping /usr/share/chainsaw/mappings/sigma-event-logs-all.yml -s'
[[ -n ${HAVE_SIGMA:-}    ]] && alias sigma-lint='sigma check'
[[ -n ${HAVE_TSHARK:-}   ]] && alias pcap-conv='tshark -q -z conv,tcp -r'
[[ -n ${HAVE_VELO:-}     ]] && alias velo='velociraptor'

# ── Detection lab: bring the Docker stack up / down ──────────────────────────
# Compose lives in $DEFENSE_DIR/docker. Override which stack with DEFENSE_STACK.
: "${DEFENSE_STACK:=detection-lab}"
_compose() {  # prefer `docker compose`, fall back to legacy `docker-compose`
  if docker compose version >/dev/null 2>&1; then docker compose "$@"
  else docker-compose "$@"; fi
}
siemup() {
  [[ -n ${HAVE_DOCKER:-} ]] || { echo "docker not installed"; return 1; }
  local f="$DEFENSE_DIR/docker/${DEFENSE_STACK}.compose.yml"
  [[ -f "$f" ]] || { echo "no compose file: $f"; return 1; }
  echo ":: bringing up '$DEFENSE_STACK' (detached)"; _compose -f "$f" up -d
}
siemdown() {
  local f="$DEFENSE_DIR/docker/${DEFENSE_STACK}.compose.yml"
  _compose -f "$f" down "$@"
}
siemlogs() {
  local f="$DEFENSE_DIR/docker/${DEFENSE_STACK}.compose.yml"
  _compose -f "$f" logs -f "$@"
}

# ── Case scaffolding ──────────────────────────────────────────────────────────
# mkcase <name> — create a dated, structured investigation workspace and cd into
# it. Sets $CASE for the session so other helpers target it. case.md (the brief)
# is created FIRST and opened so scope/authorization is written down before work.
mkcase() {
  [[ -z "$1" ]] && { echo "Usage: mkcase <incident-or-codename>"; return 1; }
  local slug name root
  slug=$(echo "$1" | tr '[:upper:] ' '[:lower:]_' | tr -cd '[:alnum:]_-')
  name="$(date +%Y%m%d)-${slug}"
  root="$CASES_DIR/$name"
  if [[ -d "$root" ]]; then
    echo "Case already exists: $root"; export CASE="$root"; cd "$root"; return 0
  fi
  mkdir -p "$root"/{evidence,network,timeline,iocs,report,notes}
  if [[ -f "$DEFENSE_DIR/defense/templates/case.md" ]]; then
    sed "s/__CASE__/$name/; s/__CREATED__/$(date -Iseconds)/" \
      "$DEFENSE_DIR/defense/templates/case.md" > "$root/case.md"
  else
    printf 'CASE: %s\nCREATED: %s\n' "$name" "$(date -Iseconds)" > "$root/case.md"
  fi
  [[ -f "$DEFENSE_DIR/defense/templates/hunt.md" ]] && cp "$DEFENSE_DIR/defense/templates/hunt.md" "$root/hunt.md"
  : > "$root/notes/notes.md"
  export CASE="$root"; cd "$root"
  echo "✓ case at $root  (\$CASE set)"
  echo "  → fill in case.md (scope + authorization) BEFORE you touch evidence."
  ${EDITOR:-nvim} "$root/case.md"
}

# gocase — fzf-jump between existing cases (mirrors Kali's `eng` widget). NOT named
# `case`: that's a zsh reserved word, so a `case` function can be defined but never called.
gocase() {
  [[ -d "$CASES_DIR" ]] || { echo "no $CASES_DIR yet — run mkcase"; return 1; }
  local sel
  sel=$(find "$CASES_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -r \
        | fzf --prompt="Case ❯ " \
              --preview="cat {}/case.md 2>/dev/null || ls -la {}")
  [[ -z "$sel" ]] && return 0
  export CASE="$sel"; cd "$sel"
}

# note — timestamped line into the active case's running notes (audit trail)
note() {
  local dir="${CASE:-$PWD}/notes"; mkdir -p "$dir"
  printf '%s  %s\n' "$(date -Iseconds)" "$*" >> "$dir/notes.md"
}

unfunction _have 2>/dev/null
```

### defense/templates/case.md

````markdown
# Case: __CASE__

- **Created:** __CREATED__
- **Analyst:**
- **Authorization / ticket ref:**     <!-- who asked, what's the mandate -->
- **Scope (hosts / accounts / time window):**
- **Out of scope — DO NOT TOUCH:**
- **Classification / handling:**       <!-- how sensitive is this evidence -->

## Summary
<!-- one-paragraph what-happened, updated as you learn -->

## Hypotheses
<!-- "an attacker doing X would leave Y" — pull from ATT&CK / Kali hacktheplanet -->

## Timeline
| time (UTC) | host | event | source artifact |
|------------|------|-------|-----------------|
|            |      |       |                 |

## IOCs
| type | value | context | confidence |
|------|-------|---------|------------|
|      |       |         |            |

## Actions taken
<!-- mirror `note` lines here as the narrative; keep provenance for every artifact -->

## Findings / recommendations
````

### defense/templates/hunt.md

````markdown
# Threat Hunt

- **Hypothesis:**            <!-- "an attacker doing X would leave Y" -->
- **ATT&CK technique(s):**   <!-- Txxxx -->
- **Data source(s):**        <!-- Sysmon 1/10, Zeek conn, 4769, ... -->
- **Validation:**            <!-- which Kali hacktheplanet fold reproduces X -->

## Query / logic
```
# Sigma is the portable source of truth; paste the rule or the compiled query here.
```

## Results
<!-- what fired, true vs false positives -->

## Outcome
- [ ] No activity found (document the coverage you confirmed)
- [ ] Activity found → open/expand a case
- [ ] Detection gap found → author a rule in detections/, then re-validate
- [ ] Tuning needed → allowlist / threshold and note why
````

### detections/README.md

````markdown
# detections/ — version-controlled detection content

Detection as code. **Sigma is the portable source of truth** — author once,
compile down to whatever SIEM the lab runs. Each rule carries its ATT&CK
technique, its data source, and a note on how it was validated (ideally
"reproduced with `<Kali hacktheplanet fold>`").

| Dir | Holds | Start from (upstream) |
|-----|-------|------------------------|
| `sigma/` | portable rules (the source of truth) | SigmaHQ |
| `sysmon/` | Sysmon config baseline(s) | Olaf Hartong `sysmon-modular`; SwiftOnSecurity |
| `network/` | Zeek scripts + Suricata tuning | Zeek pkgs; ET Open ruleset |
| `siem/` | compiled saved-searches, props/transforms, dashboards | compile from `sigma/` |

Workflow: write Sigma → convert to your backend → stand up the lab (`siemup`) →
run the matching attack from Kali → confirm it fires → tune → commit rule +
validation note. Real IOC values from cases stay in `~/cases/*/iocs`, never here.
````

### docker/README.md

````markdown
# docker/ — the detection lab

The heavy blue stack runs in containers, not on the host — that's why this repo
is distro-agnostic. `siemup` / `siemdown` (in `defense/defense.zsh`) bring a
stack up/down; pick it with `DEFENSE_STACK` (default `detection-lab`).

Why containers and not Security Onion: SO bundles Zeek + Suricata + Elastic +
Wazuh + Velociraptor behind an appliance — great as a turnkey sensor, wrong
shape for a version-controlled config repo. Here you run the same components as
discrete compose stacks, adding them as you need them.

Rules: no data volumes in git (`docker/**/data/` and `.env` are gitignored); pin
image tags (no bare `:latest`); keep secrets in a local `.env`. The shipped
`detection-lab.compose.yml` is a deliberately minimal runnable stub — swap its
body for the real stack you want.
````

### docker/detection-lab.compose.yml

```yaml
# docker/detection-lab.compose.yml
# Minimal, RUNNABLE stub so the siemup/siemdown wiring is real and testable.
# Replace the placeholder service with your actual stack (OpenSearch + Dashboards,
# Elastic, Wazuh, ...). A commented real-stack skeleton is at the bottom.
#
#   siemup        # up -d        siemlogs   # follow        siemdown   # tear down

services:
  # ── placeholder: a tiny service so `siemup` works before you pick a SIEM ──
  lab-placeholder:
    image: traefik/whoami:v1.10.2          # ~6MB, pinned; stand-in for "the console"
    container_name: lab-placeholder
    ports:
      - "127.0.0.1:8088:80"                # bound to localhost only — not LAN-exposed
    restart: unless-stopped
    # Visit http://127.0.0.1:8088 to confirm the lab is up, then swap this out.

# ── Real stack skeleton (uncomment + tune; data dirs are gitignored) ──────────
#   opensearch:
#     image: opensearchproject/opensearch:2.13.0
#     environment:
#       - discovery.type=single-node
#       - OPENSEARCH_INITIAL_ADMIN_PASSWORD=${OPENSEARCH_PW}   # from local .env (gitignored)
#     volumes:
#       - ./detection-lab/data/opensearch:/usr/share/opensearch/data
#     ports: ["127.0.0.1:9200:9200"]
#   dashboards:
#     image: opensearchproject/opensearch-dashboards:2.13.0
#     ports: ["127.0.0.1:5601:5601"]
#     depends_on: [opensearch]
```

### install/README.md

````markdown
# install/ — host tools (distro-agnostic)

No `packages.txt` here — the OS-native layer you run owns package installation,
and the heavy stack runs in `docker/`. This is the host-tool shopping list so
`bootstrap.sh` can report what's missing without assuming a package manager.

Tools probed: `docker` + compose, `jq`, `tshark`/`tcpdump`, `zeek`, `suricata`,
`chainsaw`, `hayabusa`, `sigma-cli`, `yara`, `velociraptor`, `volatility3`,
`plaso` (`log2timeline`). `bootstrap.sh` probes for these and prints which are
absent — it does not install them. If you later pin this repo to one base OS,
this file becomes that distro's real `packages.txt`.
````

## Relationship to Kali's PURPLE-TEAM.md

`PURPLE-TEAM.md` (in `dotfiles-Kali`) stays where it is — it is attacker-authored
purple content. When `dotfiles-Defense` is stood up, the two cross-link:

- `DEFENSE-METHODOLOGY.md` already references `PURPLE-TEAM.md` as the validation
  half (run the Kali fold, confirm the rule fires).
- A forward pointer can be added to `PURPLE-TEAM.md` ("defender-authored rules and
  the lab live in `dotfiles-Defense`") once the repo exists.

Nothing lifts out of `PURPLE-TEAM.md` wholesale — the split is deliberate:
attack-paired detections there, portable/deployable detection content here.
