#!/usr/bin/env bash
# scripts/test-core.sh
# ──────────────────────────────────────────────────────────────────────────────
# BEHAVIORAL tests for Core — the layer scripts/audit-core.sh's static analysis can't
# reach. audit-core.sh proves the modules PARSE (zsh -n) and that the manifest and
# exec-bits are consistent; this proves the modules actually LOAD TOGETHER in the
# canonical order and that the pure shell functions DO what they claim. A defect
# here passes every per-file `zsh -n` cleanly and still fans out to 9 OS repos —
# which is exactly the gap this file closes.
#
# Two sections, both zsh-gated and degrading gracefully (mirrors audit-core.sh):
#   A. load-order smoke test  — source every zsh module in the README's canonical
#                               order inside ONE hermetic interactive zsh and
#                               assert the whole chain loads (catches cross-module
#                               contract breakage: a module that needs a var/fn an
#                               EARLIER module must define first).
#   B. function unit tests    — exercise the pure functions in functions.zsh
#                               (mkcd / cdup / mkbak / extract) and assert behavior.
#
# Hermetic: a throwaway $HOME/$ZDOTDIR/$XDG_CACHE_HOME is used, and the plugin dirs
# are pre-seeded EMPTY so plugins.zsh's first-run `git clone` is skipped — the test
# needs no network and writes nothing outside its tempdir.
#
# Graceful degradation: with no zsh installed (a bare box), both sections SKIP and
# the script exits 0 — identical philosophy to audit-core.sh, so this is safe to
# call from CI, pre-commit, and a developer's laptop alike.
#
# Usage:
#   ./scripts/test-core.sh            # run every section
#   ./scripts/test-core.sh --quiet    # only print SKIP/FAIL + the summary
# ──────────────────────────────────────────────────────────────────────────────

# This harness embeds zsh code as single-quoted literals on purpose: the `$…`
# inside them must be expanded by the zsh CHILD, not by this bash parent. SC2016
# (un-expanded `$` in single quotes) is therefore a false positive file-wide.
# shellcheck disable=SC2016
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$HERE" || exit 1

QUIET=0
# Scope mirrors audit-core.sh: gate the slow AREA-specific sections so a per-area run
# does less. FAIL-CLOSED default (no --scope → both areas run). The cross-cutting,
# pure-bash sections (clipboard ladder, CI-classifier) ALWAYS run — they are fast and
# guard runtime artifacts shared by every area. audit-core.sh passes the classifier's
# verdict here; a bare `./scripts/test-core.sh` runs everything.
SCOPE_SHELL=1
SCOPE_NVIM=1
_set_scope() { # _set_scope <comma-list: shell,nvim | all | none>
  SCOPE_SHELL=0
  SCOPE_NVIM=0
  local tok had=0
  local IFS=,
  for tok in $1; do
    had=1
    case "$tok" in
    shell) SCOPE_SHELL=1 ;;
    nvim) SCOPE_NVIM=1 ;;
    all | full)
      SCOPE_SHELL=1
      SCOPE_NVIM=1
      ;;
    none) ;;
    *)
      printf 'test-core.sh: unknown scope %s — running full (fail-safe)\n' "$tok" >&2
      SCOPE_SHELL=1
      SCOPE_NVIM=1
      ;;
    esac
  done
  # Empty scope is ambiguous → fail SAFE to the full run (mirrors audit-core.sh);
  # `none` is the explicit "always-on checks only" token.
  ((had)) || {
    printf 'test-core.sh: empty scope — running full (fail-safe)\n' >&2
    SCOPE_SHELL=1
    SCOPE_NVIM=1
  }
}

# Same flag contract as audit-core.sh: parse EVERY arg and reject an unknown option or
# a stray extra operand instead of ignoring it; -h/--help prints usage. (audit-core.sh
# invokes this with --quiet/--scope or nothing.)
while (($#)); do
  case "$1" in
  -q | --quiet) QUIET=1 ;;
  --scope)
    # Require an explicit value (mirrors audit-core.sh): `--scope --quiet` must not
    # eat the next flag as the scope list.
    if (($# < 2)) || [[ "$2" == -* ]]; then
      printf 'test-core.sh: --scope requires a value (shell,nvim|all|none)\n' >&2
      printf 'try: test-core.sh --help\n' >&2
      exit 2
    fi
    shift
    _set_scope "$1"
    ;;
  --scope=*) _set_scope "${1#*=}" ;;
  -h | --help)
    cat <<'EOF'
usage: test-core.sh [-q|--quiet] [--scope LIST] [-h|--help]

Behavioral suite: clipboard ladder + nvim headless load + nvim event callbacks
+ zsh load-order smoke + function/unit + detection tests. Degrades gracefully
when zsh/nvim are absent.

  -q, --quiet     only print SKIP/FAIL lines and the final summary
  --scope LIST    limit the slow area sections: shell, nvim, all (default), none.
                  The clipboard + CI-classifier sections always run.
  -h, --help      show this help and exit
EOF
    exit 0
    ;;
  *)
    printf 'test-core.sh: unexpected argument: %s\n' "$1" >&2
    printf 'try: test-core.sh --help\n' >&2
    exit 2
    ;;
  esac
  shift
done

# Shared palette + pass/skip/fail/hdr/have (one definition for every gate script).
# Sourced AFTER QUIET is set so the lib's `: "${QUIET:=0}"` preserves it.
# shellcheck source=scripts/lib/common.sh
source "${BASH_SOURCE[0]%/*}/lib/common.sh"

# Wall-clock for the standalone summary (mirrors audit-core.sh) — the headless nvim
# leg can take a few seconds, so showing elapsed reads as progress, not a hang.
SECONDS=0

# When invoked from audit-core.sh (CORE_TEST_NESTED=1) the audit owns the summary,
# so we suppress ours and only signal pass/fail via the exit code.
NESTED="${CORE_TEST_NESTED:-0}"
summary() {
  [[ "$NESTED" == 1 ]] && return 0
  printf '\n%s──────── test summary ────────%s\n' "$c_blu" "$c_rst"
  printf '  %spass %d%s   %sskip %d%s   %sfail %d%s   %s(%ds)%s\n' \
    "$c_grn" "$PASS" "$c_rst" "$c_yel" "$SKIP" "$c_rst" "$c_red" "$FAIL" "$c_rst" \
    "$c_blu" "$SECONDS" "$c_rst"
}

# One throwaway sandbox for the whole run; clean it up no matter how we exit. It is
# created BEFORE the zsh gate because Section C (clipboard) is pure bash and must run
# even where zsh is absent — bin/clip's whole reason to exist is bare-box portability.
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/core-test.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT

# ── C. clipboard detection ladder (bin/clip / bin/clip-paste) ─────────────────
# bin/clip is the single highest-fan-out runtime artifact in Core — used by zsh
# (pbcopy alias), tmux (copy-pipe), AND nvim (clipboard provider), across all 9 OS
# repos — yet its WSL→macOS→Wayland→X11 ladder had no test, only `bash -n`. We drive
# the ladder HERMETICALLY: PATH is pointed at a fake bin holding a stub `uname` that
# reports the OS we want, a stub `grep` that answers the /proc/version probe, and
# stub backends that print a marker instead of touching a real clipboard — then we
# assert the RIGHT backend was exec'd. PATH is the fake dir ONLY (a real `bash`
# symlink keeps the `#!/usr/bin/env bash` shebang resolvable), so backend probing is
# fully deterministic regardless of what the host happens to have installed. Pure
# bash — runs with no zsh, exactly where bin/clip most needs to work.
hdr "clipboard detection ladder (bin/clip, bin/clip-paste)"
CLIP="$HERE/bin/clip"
CLIPPASTE="$HERE/bin/clip-paste"
CBIN="$SANDBOX/clipbin"
_real_bash="$(command -v bash)"
_real_tr="$(command -v tr)"

_stub() {
  printf '#!/bin/sh\n%s\n' "$2" >"$CBIN/$1"
  chmod +x "$CBIN/$1"
}
# Fresh fake bin + cleared env before each scenario. `bash` is symlinked so the
# shebang resolves under the stripped PATH; `uname` defaults to "Linux" and Darwin
# cases override it. The WSL probe now reads /proc/version via a bash builtin (no
# grep fork — see bin/clip), so we point CLIP_PROC_VERSION at a NON-WSL fixture; the
# WSL cases either set WSL_DISTRO_NAME or overwrite that fixture with a microsoft one.
_clip_reset() {
  rm -rf "$CBIN"
  mkdir -p "$CBIN"
  unset WSL_DISTRO_NAME WAYLAND_DISPLAY
  ln -s "$_real_bash" "$CBIN/bash"
  _stub uname 'echo Linux'
  printf 'Linux version 6.1.0-0 (gcc) #1 SMP\n' >"$CBIN/procversion"
  export CLIP_PROC_VERSION="$CBIN/procversion"
}
# Assert prog's stdout is exactly the marker the chosen backend prints.
_clip_is() { # _clip_is <label> <prog> <expected>
  local out
  out="$(printf 'payload' | PATH="$CBIN" "$2" 2>/dev/null)"
  if [[ "$out" == "$3" ]]; then pass "$1"; else fail "$1 (got '${out}', want '${3}')"; fi
}
# Assert prog exits non-zero — the no-backend-found path.
_clip_fails() { # _clip_fails <label> <prog>
  if printf 'payload' | PATH="$CBIN" "$2" >/dev/null 2>&1; then
    fail "$1 (expected non-zero exit)"
  else pass "$1"; fi
}

# clip (copy) — each scenario leaves ONLY the intended backend reachable.
_clip_reset
export WSL_DISTRO_NAME=Ubuntu
_stub clip.exe 'echo WSL'
_clip_is "clip → clip.exe when WSL_DISTRO_NAME set" "$CLIP" WSL
unset WSL_DISTRO_NAME
_clip_reset
# WSL with NO WSL_DISTRO_NAME — detection must come from /proc/version content.
printf 'Linux version 5.15.0-microsoft-standard-WSL2\n' >"$CBIN/procversion"
_stub clip.exe 'echo WSL'
_clip_is "clip → clip.exe via /proc/version (no WSL_DISTRO_NAME)" "$CLIP" WSL
_clip_reset
_stub uname 'echo Darwin'
_stub pbcopy 'echo MAC'
_clip_is "clip → pbcopy on Darwin" "$CLIP" MAC
_clip_reset
export WAYLAND_DISPLAY=wayland-0
_stub wl-copy 'echo WL'
_clip_is "clip → wl-copy under Wayland" "$CLIP" WL
unset WAYLAND_DISPLAY
_clip_reset
_stub xclip 'echo XCLIP'
_clip_is "clip → xclip on X11" "$CLIP" XCLIP
_clip_reset
_stub xsel 'echo XSEL'
_clip_is "clip → xsel when xclip absent" "$CLIP" XSEL
_clip_reset
_clip_fails "clip exits non-zero with no backend" "$CLIP"

# clip-paste (paste) — mirror ladder; the WSL leg also strips the CR powershell adds.
_clip_reset
export WSL_DISTRO_NAME=Ubuntu
ln -s "$_real_tr" "$CBIN/tr"
_stub powershell.exe 'printf "WSLPASTE\r"'
_clip_is "clip-paste → powershell + CR-strip on WSL" "$CLIPPASTE" WSLPASTE
unset WSL_DISTRO_NAME
_clip_reset
# WSL detected from /proc/version alone (no WSL_DISTRO_NAME).
printf 'Linux version 5.15.0-microsoft-standard-WSL2\n' >"$CBIN/procversion"
ln -s "$_real_tr" "$CBIN/tr"
_stub powershell.exe 'printf "WSLPASTE\r"'
_clip_is "clip-paste → powershell via /proc/version (no WSL_DISTRO_NAME)" "$CLIPPASTE" WSLPASTE
_clip_reset
_stub uname 'echo Darwin'
_stub pbpaste 'echo MAC'
_clip_is "clip-paste → pbpaste on Darwin" "$CLIPPASTE" MAC
_clip_reset
export WAYLAND_DISPLAY=wayland-0
_stub wl-paste 'echo WL'
_clip_is "clip-paste → wl-paste under Wayland" "$CLIPPASTE" WL
unset WAYLAND_DISPLAY
_clip_reset
_stub xclip 'echo XCLIP'
_clip_is "clip-paste → xclip -o on X11" "$CLIPPASTE" XCLIP
_clip_reset
_clip_fails "clip-paste exits non-zero with no backend" "$CLIPPASTE"

# ── D. Neovim config load (nvim/, headless) ───────────────────────────────────
# nvim/ is the largest body of code in Core yet was validated only by luacheck
# (static). Lua that is luacheck-clean can still be a BROKEN config — a bad vim API
# call, a malformed lazy spec — that surfaces only when nvim actually starts, and it
# fans out to 9 repos. This loads the AUTHORED Lua headlessly: the pure config layer
# (globals/options/keymaps/autocmds/clipboard/providers) AND every plugin SPEC file
# (require evaluates the spec TABLE; lazy's deferred config/keys callbacks do NOT run,
# so no plugin needs to be installed — every plugin `require` in this tree is inside
# such a callback). Hermetic + offline, mirroring how the zsh tests pre-seed empty
# plugin dirs; graceful skip when nvim is absent, exactly like the linters. Real
# plugin RUNTIME (the deferred callbacks) is out of scope — luacheck covers its syntax.
hdr "neovim config load (nvim/ headless)"
if ! ((SCOPE_NVIM)); then
  skip "nvim config load (out of scope)"
elif have nvim; then
  probe="$SANDBOX/nvim-probe.lua"
  cat >"$probe" <<'LUA'
vim.opt.runtimepath:prepend(vim.env.CORE_NVIM_DIR)
local errs = {}
local function try(mod)
  local ok, err = pcall(require, mod)
  if not ok then errs[#errs + 1] = mod .. " → " .. tostring(err) end
end
for _, m in ipairs({
  "gerrrt.config.globals", "gerrrt.config.options", "gerrrt.config.keymaps",
  "gerrrt.config.autocmds", "gerrrt.config.clipboard", "gerrrt.config.providers",
}) do try(m) end
-- :checkhealth gerrrt module — loaded only by checkhealth at runtime, so this is its
-- only load gate. Require it AND assert it exposes a check() function.
do
  local ok, m = pcall(require, "gerrrt.health")
  if not ok then
    errs[#errs + 1] = "gerrrt.health → " .. tostring(m)
  elseif type(m) ~= "table" or type(m.check) ~= "function" then
    errs[#errs + 1] = "gerrrt.health → did not return a table with a check() function"
  end
end
-- every plugin spec must require cleanly and return a lazy spec table
local pdir = vim.env.CORE_NVIM_DIR .. "/lua/gerrrt/plugins"
for _, f in ipairs(vim.fn.readdir(pdir) or {}) do
  local name = f:match("^(.+)%.lua$")
  if name then
    local mod = "gerrrt.plugins." .. name
    local ok, res = pcall(require, mod)
    if not ok then
      errs[#errs + 1] = mod .. " → " .. tostring(res)
    elseif type(res) ~= "table" then
      errs[#errs + 1] = mod .. " → did not return a spec table"
    end
  end
end
-- LSP layer: servers/init.lua wires 13 server configs + the on_attach/diagnostics
-- helpers, but ALL of it runs inside a deferred plugin callback (plugins/nvim-lspconfig)
-- — so the loop above never touches it, and luacheck (static) was its only gate. A bad
-- vim.lsp.config{} call or a typo'd capability there is luacheck-clean and breaks only on
-- first file-open, then fans out 9×. Close that: require utils.lsp/diagnostics, and every
-- servers/* LEAF (each returns a `function(capabilities)`; requiring it evaluates the file
-- WITHOUT calling it, so no blink.cmp/lspconfig need be installed). servers/init.lua itself
-- is skipped — it require()s blink.cmp, a plugin absent from this hermetic probe.
for _, m in ipairs({ "gerrrt.utils.lsp", "gerrrt.utils.diagnostics" }) do try(m) end
local sdir = vim.env.CORE_NVIM_DIR .. "/lua/gerrrt/servers"
for _, f in ipairs(vim.fn.readdir(sdir) or {}) do
  local name = f:match("^(.+)%.lua$")
  if name and name ~= "init" then
    local mod = "gerrrt.servers." .. name
    local ok, res = pcall(require, mod)
    if not ok then
      errs[#errs + 1] = mod .. " → " .. tostring(res)
    elseif type(res) ~= "function" then
      errs[#errs + 1] = mod .. " → did not return a function(capabilities)"
    end
  end
end
if #errs > 0 then
  io.stderr:write(table.concat(errs, "\n") .. "\n")
  vim.cmd("cquit 1")
end
vim.cmd("quitall!")
LUA
  # -u the probe AS init (so the repo's real bootstrap never runs → no lazy clone, no
  # network), headless, no shada/swap. A clean exit means every authored module and
  # spec loaded; the probe `:cquit 1`s with the offending modules on stderr otherwise.
  nvim_err="$SANDBOX/nvim.err"
  if CORE_NVIM_DIR="$HERE/nvim" nvim --headless -u "$probe" -i NONE -n +qa >/dev/null 2>"$nvim_err"; then
    pass "nvim loaded all config + plugin specs + LSP server configs (no lua errors)"
  else
    fail "nvim config/plugin-spec/lsp load error:"
    [[ -s "$nvim_err" ]] && sed 's/^/    /' "$nvim_err" >&2
  fi
else
  skip "nvim config load (nvim not installed — runs in CI)"
fi

# ── D2. Neovim event-driven autocmd callbacks (nvim/, headless) ───────────────
# Section D proves the modules LOAD; it does not prove their EVENT CALLBACKS run.
# An autocmd registers fine and only its callback fires later — on a yank, a save,
# an LSP attach — so a bad vim API call inside one is luacheck-clean, load-clean, and
# breaks only when you actually edit. That blind spot shipped a real bug: the
# TextYankPost highlight called a non-existent `vim.hl.hl_op`, throwing on every yank
# AND delete (TextYankPost fires on both) while the edit still ran — a red error with
# no failing gate, fanned out to 9 repos. This closes it: load the autocmds, then
# FIRE the events and assert the callbacks ran clean.
#
# Events are triggered via post-startup `-c` commands (NOT inside the `-u` init): an
# autocmd error during init makes headless nvim block on a "Press ENTER" prompt,
# whereas a `-c` error is reported and nvim proceeds to the next command — so the
# gate can never hang in CI. The require itself stays in `-u` and `cquit`s on failure
# (no prompt). Detection is STDERR-NON-EMPTY, not exit code: a fired-callback error
# does not change nvim's exit status (both clean and broken runs exit 0), it only
# prints — exactly the signature the bug has. BufWritePre (format-on-save) and
# LspAttach are deliberately NOT fired here: their callbacks require plugins
# (mini.trailspace/conform) or a live LSP attach, neither present in this hermetic
# probe — luacheck covers their syntax; runtime is out of scope.
hdr "neovim event callbacks (nvim/ headless)"
if ! ((SCOPE_NVIM)); then
  skip "nvim event callbacks (out of scope)"
elif have nvim; then
  evt_probe="$SANDBOX/nvim-events.lua"
  cat >"$evt_probe" <<'LUA'
vim.opt.runtimepath:prepend(vim.env.CORE_NVIM_DIR)
-- Register the autocmds. A require failure cquit's immediately (no ENTER prompt);
-- the EVENTS themselves are fired by the caller's -c flags, after startup.
local ok, err = pcall(require, "gerrrt.config.autocmds")
if not ok then
  io.stderr:write("require gerrrt.config.autocmds → " .. tostring(err) .. "\n")
  vim.cmd("cquit 1")
end
LUA
  evt_file="$SANDBOX/probe.txt"
  printf 'one\ntwo\nthree\n' >"$evt_file"
  evt_err="$SANDBOX/nvim-events.err"
  # Fire each registered event once: yank + delete (TextYankPost — the regression
  # above), a markdown FileType (the per-filetype view options), and a real file open
  # (BufReadPost — cursor restore). Any callback that throws prints to stderr. The file
  # path is passed via $CORE_EVT_FILE and opened through fnameescape() rather than
  # interpolated into the Ex command, so a $SANDBOX/$TMPDIR containing spaces is safe.
  CORE_NVIM_DIR="$HERE/nvim" CORE_EVT_FILE="$evt_file" nvim --headless -u "$evt_probe" -i NONE -n \
    -c 'call setline(1, ["alpha","bravo","charlie"])' \
    -c 'normal! yy' -c 'normal! dd' \
    -c 'setfiletype markdown' \
    -c 'execute "edit" fnameescape($CORE_EVT_FILE)' \
    -c 'qa!' </dev/null >/dev/null 2>"$evt_err"
  if [[ -s "$evt_err" ]]; then
    fail "nvim autocmd callback errored when fired (e.g. the yank/delete highlight):"
    sed 's/^/    /' "$evt_err" >&2
  else
    pass "nvim event callbacks fired clean (TextYankPost yank+delete, FileType, BufReadPost)"
  fi
else
  skip "nvim event callbacks (nvim not installed — runs in CI)"
fi

# ── E. CI path classifier (scripts/ci-classify.sh) ────────────────────────────
# ci.yml's change-detection picks which gates run per push. That logic now lives in
# scripts/ci-classify.sh (pulled out of the workflow YAML so it can be linted + tested);
# this asserts the contract the workflow depends on: known paths map to the right gates,
# the __ALL__ sentinel runs everything, and — the regression that matters — an
# UNRECOGNISED top-level path FAILS CLOSED to the full run instead of silently skipping
# a gate on the 9-repo fan-out. Pure bash, so it runs even where zsh/nvim are absent.
hdr "CI path classifier (scripts/ci-classify.sh)"
CLASSIFY="$HERE/scripts/ci-classify.sh"
_classify_is() { # _classify_is <label> <newline-input> <want-shell> <want-nvim>
  local got
  got="$(printf '%s\n' "$2" | "$CLASSIFY" 2>/dev/null)"
  if [[ "$got" == "shell=$3"$'\n'"nvim=$4" ]]; then
    pass "$1"
  else
    fail "$1 (got: ${got//$'\n'/ }; want shell=$3 nvim=$4)"
  fi
}
_classify_is "zsh/ change → shell gate only" 'zsh/ui.zsh' true false
_classify_is "nvim/ change → nvim gate only" 'nvim/init.lua' false true
_classify_is "docs (*.md) change → no gate" 'README.md' false false
_classify_is "infra (scripts/) change → full run" 'scripts/audit-core.sh' true true
_classify_is "__ALL__ sentinel → full run" '__ALL__' true true
_classify_is "unrecognised path → FAIL CLOSED to full run" 'newdir/thing.xyz' true true
_classify_is "mixed shell+nvim set → union of both" $'zsh/ui.zsh\nnvim/init.lua' true true

# ── zsh-gated sections (A load-order, B function units) ───────────────────────
# Everything below needs a real zsh. On a bare box we SKIP it (not fail) and fall
# through to the shared summary, so a Section-C failure still surfaces as exit 1.
if ! ((SCOPE_SHELL)) || ! have zsh; then
  hdr "zsh behavioral sections (load-order + function units)"
  if ! ((SCOPE_SHELL)); then
    skip "zsh behavioral sections (out of scope)"
  else
    skip "load-order smoke + function units (zsh not installed — runs in CI)"
  fi
  summary
  ((FAIL == 0)) || {
    [[ "$NESTED" == 1 ]] || printf '%stests FAILED%s\n' "$c_red" "$c_rst" >&2
    exit 1
  }
  [[ "$NESTED" == 1 ]] || printf '%stests OK%s\n' "$c_grn" "$c_rst"
  exit 0
fi

# ── A. load-order smoke test ──────────────────────────────────────────────────
hdr "load-order smoke test (canonical .zshrc chain)"
# The README/manifest canonical order. There is no os/local module here — those
# are supplied by each OS repo's loader and are out of Core's scope.
CORE_MODULES=(tools ui options history aliases git functions fzf bindings plugins op maint update)

# Pre-seed empty plugin dirs so plugins.zsh's first-run clone is a no-op (hermetic,
# no network). _zplugin_load finds the dir, skips the clone, finds no source file,
# and moves on — exercising the load-order logic without pulling from GitHub.
mkdir -p "$SANDBOX/zdot/plugins"
for plug in zsh-defer zsh-vi-mode zsh-history-substring-search \
  zsh-autosuggestions fast-syntax-highlighting fzf-tab zsh-you-should-use; do
  mkdir -p "$SANDBOX/zdot/plugins/$plug"
done

# Generate the sandbox .zshrc: source every Core module in canonical order, then
# print a sentinel. We deliberately do NOT key success on each module's exit code —
# a module whose LAST statement is a false guard (e.g. aliases.zsh ends on
# `[[ -n $HAVE_GPING ]] && alias ping=gping`, false on a bare box) returns non-zero
# while having loaded perfectly. The real signal of a broken load-order contract is
# a RUNTIME error on stderr (a module using a fn/widget/var an EARLIER module must
# define first) — so we assert: the chain REACHED THE END (sentinel) with CLEAN
# stderr. Parse errors are already caught per-file by audit-core.sh's `zsh -n`.
export CORE_DIR="$HERE/zsh"
{
  printf 'for _m in %s; do source "$CORE_DIR/$_m.zsh"; done\n' "${CORE_MODULES[*]}"
  printf 'print -r -- "SMOKE_OK"\n'
} >"$SANDBOX/zdot/.zshrc"

# Run one interactive zsh with the sandbox as HOME + ZDOTDIR. -i so the modules'
# `[[ $- == *i* ]]` guards pass and the interactive paths actually execute.
smoke_out="$(
  HOME="$SANDBOX" ZDOTDIR="$SANDBOX/zdot" \
    XDG_CACHE_HOME="$SANDBOX/cache" XDG_STATE_HOME="$SANDBOX/state" \
    XDG_RUNTIME_DIR="$SANDBOX/run" CORE_DIR="$CORE_DIR" \
    zsh -i -c exit 2>"$SANDBOX/smoke.err"
)"
# High-signal zsh runtime-error markers — what a real load-order break looks like.
smoke_errs="$(grep -Ei \
  'command not found|parse error|: no such file or directory|not defined|bad pattern|bad math expression|maximum nested' \
  "$SANDBOX/smoke.err" 2>/dev/null || true)"
if ! printf '%s' "$smoke_out" | grep -q '^SMOKE_OK$'; then
  fail "load-order chain did not reach the end (no SMOKE_OK sentinel — a module aborted)"
  [[ -s "$SANDBOX/smoke.err" ]] && sed 's/^/    /' "$SANDBOX/smoke.err" >&2
elif [[ -n "$smoke_errs" ]]; then
  fail "runtime errors during canonical load (load-order contract broken):"
  printf '%s\n' "$smoke_errs" | sed 's/^/    /' >&2
else
  pass "all ${#CORE_MODULES[@]} modules loaded in canonical order (clean stderr)"
fi

# ── A2. consumer integration (Core + os/local layers) ─────────────────────────
# Core NEVER loads alone in production: each OS repo's .zshrc sources it in canonical
# order and THEN its own os.zsh + local.zsh (README: tools→…→update→os→local). Section
# A proves Core-in-isolation; this proves the documented CONSUMPTION — that the Core→OS
# CONTRACT holds at the real 9-repo fan-out shape. The os.zsh stub here uses exactly
# what an OS layer relies on Core to have left defined: _cache_eval (tools.zsh's API for
# the OS layer's gh/uv/ty inits — NOT unfunctioned like _have is), the _core_* UX
# primitives, and an alias override (the macOS rm→trash pattern). local.zsh overrides a
# Core default. If Core ever stops exporting one of those, this fails — where Section A,
# loading Core alone, would stay green.
hdr "consumer integration (Core + os/local layers, canonical loader)"
INTEG="$SANDBOX/integ"
mkdir -p "$INTEG/plugins"
for plug in zsh-defer zsh-vi-mode zsh-history-substring-search \
  zsh-autosuggestions fast-syntax-highlighting fzf-tab zsh-you-should-use; do
  mkdir -p "$INTEG/plugins/$plug"
done
# os.zsh: realistic OS-layer file. Exercises the Core helpers an OS repo depends on;
# any reference to an undefined helper prints to stderr (the failure signal below).
cat >"$INTEG/os.zsh" <<'OSZSH'
# stub os.zsh — must be able to use the API Core promises the OS layer.
(( $+functions[_cache_eval] )) || print -u2 "os.zsh: _cache_eval missing (tools.zsh API gone)"
(( $+functions[_core_ok]    )) || print -u2 "os.zsh: _core_ok missing (ui.zsh API gone)"
# the documented gh/uv/ty pattern: _cache_eval a tool AFTER options.zsh set NO_CLOBBER.
# The generator must emit SOURCEABLE zsh (real tools emit an init script); a comment is
# a valid no-op init and proves the generate→cache→source path works under NO_CLOBBER.
_cache_eval faketool printf '# faketool cached init (integration stub)\n' >/dev/null
alias rm='rm -i'   # OS layer overriding a safety net (macOS does rm→trash here)
OSZSH
# local.zsh: machine-specific overrides (identity/toggles). Overriding a Core default
# is the whole reason it loads LAST.
cat >"$INTEG/local.zsh" <<'LOCALZSH'
# stub local.zsh — last word on this machine.
UPDATE_CHECK_ENABLED=0
LOCALZSH
{
  printf 'for _m in %s; do source "$CORE_DIR/$_m.zsh"; done\n' "${CORE_MODULES[*]}"
  printf 'source "$ZDOTDIR/os.zsh"\n'
  printf 'source "$ZDOTDIR/local.zsh"\n'
  printf 'print -r -- "INTEG_OK"\n'
} >"$INTEG/.zshrc"
integ_out="$(
  HOME="$SANDBOX" ZDOTDIR="$INTEG" \
    XDG_CACHE_HOME="$SANDBOX/integ-cache" XDG_STATE_HOME="$SANDBOX/integ-state" \
    XDG_RUNTIME_DIR="$SANDBOX/run" CORE_DIR="$CORE_DIR" \
    zsh -i -c exit 2>"$INTEG/integ.err"
)"
integ_errs="$(grep -Ei \
  'command not found|parse error|: no such file or directory|not defined|missing|bad pattern|bad math expression|maximum nested' \
  "$INTEG/integ.err" 2>/dev/null || true)"
if ! printf '%s' "$integ_out" | grep -q '^INTEG_OK$'; then
  fail "consumer load (Core+os+local) did not reach the end — a layer aborted"
  [[ -s "$INTEG/integ.err" ]] && sed 's/^/    /' "$INTEG/integ.err" >&2
elif [[ -n "$integ_errs" ]]; then
  fail "errors during consumer load (Core→OS contract broken):"
  printf '%s\n' "$integ_errs" | sed 's/^/    /' >&2
else
  pass "Core + os + local loaded in canonical order (Core→OS contract holds)"
fi

# ── B. function unit tests ────────────────────────────────────────────────────
hdr "function unit tests (functions.zsh)"
FN="$HERE/zsh/functions.zsh"
# functions.zsh now routes its errors through ui.zsh's _core_* helpers, so the
# unit shell must source ui.zsh FIRST — the same ordering the real loader uses
# (tools → ui → … → functions). It loads before functions in every assertion below.
UI="$HERE/zsh/ui.zsh"

# Run an assertion under zsh; $1 = label, $2 = zsh body that must exit 0.
# On FAILURE we capture the child's combined stdout+stderr and print it INDENTED
# (mirroring the nvim/smoke sections above) — a red unit test must say WHY, not just
# its label, or a CI failure that fans out to 9 repos forces a local re-reproduction.
# On PASS the output is discarded, so the expected _core_err/usage noise stays silent.
check() { # check <label> <zsh-body>
  local out
  if out="$(HOME="$SANDBOX" zsh -fc "source '$UI' || exit 1; source '$FN' || exit 1; $2" 2>&1)"; then
    pass "$1"
  else
    fail "$1"
    [[ -n "$out" ]] && printf '%s\n' "$out" | sed 's/^/    /' >&2
  fi
}

# Like check, but SKIP (not fail) when a required external tool is absent — so the
# archive round-trip tests degrade gracefully on a bare box, mirroring the linter
# skips above. extract's own first branch is `ouch` when HAVE_OUCH is set; under
# `zsh -fc` that var is unset, so these exercise the hand-rolled case fallback.
check_dep() { # check_dep <label> <dep> <zsh-body>
  if ! have "$2"; then
    skip "$1 ($2 not installed)"
    return
  fi
  local out
  if out="$(HOME="$SANDBOX" zsh -fc "source '$UI' || exit 1; source '$FN' || exit 1; $3" 2>&1)"; then
    pass "$1"
  else
    fail "$1"
    [[ -n "$out" ]] && printf '%s\n' "$out" | sed 's/^/    /' >&2
  fi
}

check "mkcd creates and enters a nested dir" \
  'd=$(mktemp -d); cd "$d"; mkcd a/b/c; [[ ${PWD:t} == c && -d "$d/a/b/c" ]]'
check "cdup climbs N directories" \
  'd=$(mktemp -d); mkdir -p "$d/a/b/c"; cd "$d/a/b/c"; cdup 2; [[ ${PWD:t} == a ]]'
# Defensive input guards (U1): a bad count / missing file / bad port must be REJECTED
# in Core's voice (non-zero), not silently no-op or handed to cp/python to fail raw.
check "cdup rejects a non-numeric count" \
  'cdup abc 2>/dev/null; (( $? != 0 ))'
check "cdup rejects a zero count" \
  'cdup 0 2>/dev/null; (( $? != 0 ))'
check "mkbak writes a timestamped .bak copy" \
  'd=$(mktemp -d); cd "$d"; print hi > f; mkbak f; set -- f.*.bak; [[ -f $1 ]]'
check "mkbak's .bak is byte-identical to the original" \
  'd=$(mktemp -d); cd "$d"; print -r -- payload > f; mkbak f; set -- f.*.bak; [[ -f $1 && "$(cat -- $1)" == payload ]]'
check "mkbak rejects a missing file" \
  'mkbak /no/such/file 2>/dev/null; (( $? != 0 ))'
check "mkbak with no argument is rejected" \
  'mkbak 2>/dev/null; (( $? != 0 ))'
check "serve rejects a non-numeric port" \
  'serve abc 2>/dev/null; (( $? != 0 ))'
check "serve rejects an out-of-range port" \
  'serve 99999 2>/dev/null; (( $? != 0 ))'
# Uniform -h/--help contract (U6): every user-facing verb answers --help on STDOUT
# and returns 0 (a help REQUEST is success, not misuse). This also guards the bugs
# where --help used to be mis-read as an operand — serve as a bad port, extract as a
# missing file (both returned non-zero); the guard must short-circuit before that.
check "mkcd --help prints usage to stdout and returns 0" \
  'out=$(mkcd --help); (( $? == 0 )) && [[ $out == *"usage: mkcd"* ]]'
check "serve --help returns 0 (not mis-read as a bad port)" \
  'out=$(serve --help); (( $? == 0 )) && [[ $out == *"usage: serve"* ]]'
check "extract -h returns 0 (not mis-read as a missing file)" \
  'out=$(extract -h); (( $? == 0 )) && [[ $out == *"usage: extract"* ]]'
# core-help (U5): the width-aware renderer must emit every verb and never crash on its
# kw arithmetic — including a pathologically narrow terminal where the key column clamps.
check "core-help renders all verbs (wide terminal)" \
  'out=$(COLUMNS=120 core-help 2>&1); (( $? == 0 )) && [[ $out == *mkcd* && $out == *"maint-install"* && $out == *serve* ]]'
check "core-help renders cleanly on a pathologically narrow terminal" \
  'out=$(COLUMNS=12 core-help 2>&1); (( $? == 0 )) && [[ $out == *mkcd* ]]'
check "extract rejects a non-existent file" \
  'extract /no/such/archive.tar.gz; (( $? != 0 ))'
check "extract rejects a known file of unknown format" \
  'd=$(mktemp -d); cd "$d"; : > mystery.qqq; extract mystery.qqq; (( $? != 0 ))'
check_dep "extract round-trips a .tar.gz" tar \
  'd=$(mktemp -d); cd "$d"; mkdir src; print -r -- hi > src/a.txt; tar czf a.tgz src; rm -rf src; extract a.tgz; [[ -f src/a.txt && "$(cat -- src/a.txt)" == hi ]]'
check_dep "extract round-trips a .gz" gzip \
  'd=$(mktemp -d); cd "$d"; print -r -- hi > f.txt; gzip f.txt; extract f.txt.gz; [[ -f f.txt && "$(cat -- f.txt)" == hi ]]'
# Defensive guards (U4): a multi-entry "tarbomb" must be flagged (with no TTY the
# contain-prompt declines and it extracts in place — both files land, we warned), and
# an extract that WOULD clobber an existing entry must abort untouched rather than
# silently overwrite. _core_confirm declining on no-TTY is what makes both deterministic.
check_dep "extract warns on a tarbomb but still unpacks (no TTY)" tar \
  'd=$(mktemp -d); cd "$d"; print x > one; print y > two; tar czf bomb.tgz one two; rm one two; extract bomb.tgz </dev/null; [[ -f one && -f two ]]'
check_dep "extract refuses to clobber an existing entry (no TTY)" tar \
  'd=$(mktemp -d); cd "$d"; mkdir src; print new > src/a.txt; tar czf a.tgz src; print OLD > src/a.txt; extract a.tgz </dev/null; rc=$?; [[ "$(cat -- src/a.txt)" == OLD && $rc -ne 0 ]]'
# gz/bz2 write NEXT TO the archive path, not into $PWD: `extract /dir/f.gz` must guard
# /dir/f, not ./f. Run it from a DIFFERENT cwd so a basename-only check would miss the
# clobber and overwrite (the bug this asserts against).
check_dep "extract guards the gz output at the archive's path, not \$PWD" gzip \
  'd=$(mktemp -d); sub="$d/sub"; mkdir -p "$sub"; print new > "$sub/f.txt"; gzip "$sub/f.txt"; print OLD > "$sub/f.txt"; cd "$d"; extract "$sub/f.txt.gz" </dev/null; rc=$?; [[ "$(cat -- "$sub/f.txt")" == OLD && $rc -ne 0 ]]'

# ── E. detection + UX unit tests (ui.zsh / update.zsh / maint.zsh) ────────────
# Sections A/B and audit-core.sh's static pass leave the highest-LOGIC, highest
# fan-out helpers unproven: the package-manager and scheduler detection LADDERS
# (which differ per distro and silently mis-fire) and ui.zsh's defensive no-TTY
# confirm. A regression in any of these ships to all 9 OS repos — exactly what a
# behavioral gate must catch. Each is driven HERMETICALLY against a stubbed PATH
# (the same technique the clip ladder in section C uses), so the result is
# deterministic on every CI userland (glibc / BSD / musl) regardless of what's
# actually installed there.
hdr "detection + UX unit tests (ui / update / maint)"
_real_zsh="$(command -v zsh)"
UPD="$HERE/zsh/update.zsh"
MNT="$HERE/zsh/maint.zsh"
# A fake bin dir holding ONE stub command, used to pin a detection ladder's answer.
PMBIN="$SANDBOX/pmbin"
_pm_only() {
  rm -rf "$PMBIN"
  mkdir -p "$PMBIN"
  [[ -n "${1:-}" ]] && {
    printf '#!/bin/sh\n:\n' >"$PMBIN/$1"
    chmod +x "$PMBIN/$1"
  }
}

# Run a zsh assertion that must exit 0; on failure print the captured output indented
# (same diagnostics contract as check() above). Trailing args are `VAR=VAL` env prefixes
# applied to the child — used to isolate PATH for the detection ladders. Runs INTERACTIVE
# (-i): update.zsh gates its whole body behind `[[ $- == *i* ]]`, so a non-interactive
# `-fc` would source to a no-op. `$_real_zsh` (absolute) keeps zsh reachable even when
# the test isolates PATH down to the stub dir.
ucheck() { # ucheck <label> <zsh-body> [VAR=VAL ...]
  local label="$1" body="$2"
  shift 2
  local out
  if out="$(HOME="$SANDBOX" env "$@" "$_real_zsh" -fic "$body" 2>&1)"; then
    pass "$label"
  else
    fail "$label"
    [[ -n "$out" ]] && printf '%s\n' "$out" | sed 's/^/    /' >&2
  fi
}

# ui.zsh: _core_confirm is DEFENSIVE — with no controlling TTY (captured run, stdin
# redirected) it must DECLINE (non-zero), so wrapping a destructive action (please/up)
# in it is fail-safe in a pipe/cron/CI context instead of blocking or assuming yes.
ucheck "ui: _core_confirm declines with no TTY (fail-safe)" \
  "source '$UI'; _core_confirm 'x' </dev/null; (( \$? != 0 ))"

# ui.zsh: _core_spin must return the WRAPPED command's exit code (the non-TTY path
# runs it directly) — the contract plugins.zsh's first-run installer relies on to know
# a clone step failed. true → 0, false → non-zero.
ucheck "ui: _core_spin propagates the wrapped command's exit code" \
  "source '$UI'; _core_spin t true 2>/dev/null && ! _core_spin t false 2>/dev/null"

# update.zsh: _pkgup_mgr must pick the manager that's actually on PATH. Isolate PATH to
# a lone apt-get stub (so the brew/pacman/dnf/zypper arms above it all miss) and disable
# the two background startup hooks, so the answer is deterministic on any runner.
_pm_only apt-get
ucheck "update: _pkgup_mgr detects apt from an isolated PATH" \
  "source '$UPD'; [[ \$(_pkgup_mgr) == apt ]]" \
  PATH="$PMBIN" UPDATE_CHECK_ENABLED=0 CORE_WELCOME=0
# …and reports `none` when NO supported manager is reachable (the silent-stay path).
_pm_only ""
ucheck "update: _pkgup_mgr reports none on a bare PATH" \
  "source '$UPD'; [[ \$(_pkgup_mgr) == none ]]" \
  PATH="$PMBIN" UPDATE_CHECK_ENABLED=0 CORE_WELCOME=0
# up --help must print usage and return 0 WITHOUT attempting an update — the bug the
# help guard fixes (it used to fall through, not being -y, and run the upgrade). Run
# on a bare PATH so a regressed guard reaching _pkgup_mgr → none → returns 1, failing
# this test loudly instead of silently passing.
_pm_only ""
ucheck "update: up --help returns 0 and does not attempt an update" \
  "source '$UI'; source '$UPD'; out=\$(up --help); (( \$? == 0 )) && [[ \$out == *'usage: up'* ]]" \
  PATH="$PMBIN" UPDATE_CHECK_ENABLED=0 CORE_WELCOME=0
# up's pre-confirm PREVIEW: _pkgup_list surfaces the upgradable package NAMES (the
# count is already in the nudge) so `up` shows what will change before the destructive
# sync. Stub apt-get's `-s upgrade` simulate output; mgr pins to apt via isolated PATH.
rm -rf "$PMBIN"
mkdir -p "$PMBIN"
printf '#!/bin/sh\ncase "$*" in *"-s upgrade"*) printf "Inst foo [1.0] (1.1)\\nInst bar [2.0] (2.1)\\n";; esac\n' >"$PMBIN/apt-get"
chmod +x "$PMBIN/apt-get"
# The apt arm pipes to awk; the isolated PATH has only the stub, so symlink the real
# awk in (like the clip ladder symlinks bash/tr). It's not a package manager, so
# _pkgup_mgr still resolves to apt — the isolation we want.
ln -s "$(command -v awk)" "$PMBIN/awk"
ucheck "update: _pkgup_list surfaces upgradable package names (apt)" \
  "source '$UPD'; out=\$(_pkgup_list); [[ \$out == *foo* && \$out == *bar* ]]" \
  PATH="$PMBIN" UPDATE_CHECK_ENABLED=0 CORE_WELCOME=0

# maint.zsh: _maint_scheduler must always resolve to a REAL scheduler token, never empty
# or garbage. With systemctl absent (isolated PATH) and crontab present as the fallback,
# it lands on cron (Linux/Alpine) or launchd (macOS, OSTYPE-driven) — both valid — so the
# assertion is the same green on every CI userland while still exercising the full ladder.
_pm_only crontab
ucheck "maint: _maint_scheduler resolves to a valid scheduler" \
  "source '$UI'; source '$MNT'; [[ \$(_maint_scheduler) == (systemd|launchd|cron) ]]" \
  PATH="$PMBIN"

# update.zsh: the first-run welcome (U2 — the cheat-sheet discoverability hint) must
# greet EXACTLY ONCE per machine. Drive _core_welcome directly (the TTY gate lives at
# its call site, so a captured run can exercise the greet+sentinel logic): first call
# prints the core-help pointer and persists the sentinel; a second call is silent.
# An isolated XDG_STATE_HOME keeps the sentinel out of the shared sandbox.
ucheck "update: _core_welcome greets once, then the sentinel silences it" \
  "source '$UPD'; o1=\$(_core_welcome); [[ \$o1 == *core-help* ]] || exit 1; [[ -e \$XDG_STATE_HOME/dotfiles-core/.welcomed ]] || exit 1; o2=\$(_core_welcome); [[ -z \$o2 ]]" \
  XDG_STATE_HOME="$SANDBOX/welcome-once" NO_COLOR=1 UPDATE_CHECK_ENABLED=0 CORE_WELCOME=0
# …and the startup hook stays SILENT without an interactive tty (captured/piped/CI):
# sourcing update.zsh prints no greet and writes no sentinel, so it never spams logs.
ucheck "update: welcome stays silent (no greet, no sentinel) without a tty" \
  "o=\$(source '$UPD'); [[ \$o != *core-help* && ! -e \$XDG_STATE_HOME/dotfiles-core/.welcomed ]]" \
  XDG_STATE_HOME="$SANDBOX/welcome-notty" NO_COLOR=1 UPDATE_CHECK_ENABLED=0 CORE_WELCOME=1

# completions (U3): every first-party verb must have a #compdef that compinit picks up
# off the vendored fpath dir — a missing/typo'd tag means no tab-completion for that
# command across all 9 repos, with nothing else to catch it. Put the dir on fpath (as
# options.zsh does), run compinit, and assert each verb resolved to a completion.
ucheck "completions: compinit wires every Core first-party completion" \
  "fpath=('$HERE/zsh/completions' \$fpath); autoload -Uz compinit && compinit -u -d '$SANDBOX/zcd-comp' >/dev/null 2>&1; for c in mkcd mkbak extract up serve cdup fcd please core-help cheat; do [[ -n \${_comps[\$c]:-} ]] || { print \"no completion registered for: \$c\"; exit 1; }; done"

# ── summary ───────────────────────────────────────────────────────────────────
summary
((FAIL == 0)) || {
  [[ "$NESTED" == 1 ]] || printf '%stests FAILED%s\n' "$c_red" "$c_rst" >&2
  exit 1
}
[[ "$NESTED" == 1 ]] || printf '%stests OK%s\n' "$c_grn" "$c_rst"
