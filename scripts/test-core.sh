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
# Same flag contract as audit-core.sh: parse EVERY arg and reject an unknown option or
# a stray extra operand instead of ignoring it; -h/--help prints usage. (audit-core.sh
# invokes this with --quiet or nothing.)
while (($#)); do
  case "$1" in
  -q | --quiet) QUIET=1 ;;
  -h | --help)
    cat <<'EOF'
usage: test-core.sh [-q|--quiet] [-h|--help]

Behavioral suite: clipboard ladder + nvim headless load + zsh load-order smoke
+ function/unit + detection tests. Degrades gracefully when zsh/nvim are absent.

  -q, --quiet   only print SKIP/FAIL lines and the final summary
  -h, --help    show this help and exit
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

# When invoked from audit-core.sh (CORE_TEST_NESTED=1) the audit owns the summary,
# so we suppress ours and only signal pass/fail via the exit code.
NESTED="${CORE_TEST_NESTED:-0}"
summary() {
  [[ "$NESTED" == 1 ]] && return 0
  printf '\n%s──────── test summary ────────%s\n' "$c_blu" "$c_rst"
  printf '  %spass %d%s   %sskip %d%s   %sfail %d%s\n' \
    "$c_grn" "$PASS" "$c_rst" "$c_yel" "$SKIP" "$c_rst" "$c_red" "$FAIL" "$c_rst"
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
# shebang resolves under the stripped PATH; `uname`/`grep` default to "Linux, not
# WSL" and Darwin/WSL cases override them.
_clip_reset() {
  rm -rf "$CBIN"
  mkdir -p "$CBIN"
  unset WSL_DISTRO_NAME WAYLAND_DISPLAY
  ln -s "$_real_bash" "$CBIN/bash"
  _stub uname 'echo Linux'
  _stub grep 'exit 1'
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
if have nvim; then
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
if ! have zsh; then
  hdr "zsh behavioral sections (load-order + function units)"
  skip "load-order smoke + function units (zsh not installed — runs in CI)"
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
check "mkbak writes a timestamped .bak copy" \
  'd=$(mktemp -d); cd "$d"; print hi > f; mkbak f; set -- f.*.bak; [[ -f $1 ]]'
check "mkbak's .bak is byte-identical to the original" \
  'd=$(mktemp -d); cd "$d"; print -r -- payload > f; mkbak f; set -- f.*.bak; [[ -f $1 && "$(cat -- $1)" == payload ]]'
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

# maint.zsh: _maint_scheduler must always resolve to a REAL scheduler token, never empty
# or garbage. With systemctl absent (isolated PATH) and crontab present as the fallback,
# it lands on cron (Linux/Alpine) or launchd (macOS, OSTYPE-driven) — both valid — so the
# assertion is the same green on every CI userland while still exercising the full ladder.
_pm_only crontab
ucheck "maint: _maint_scheduler resolves to a valid scheduler" \
  "source '$UI'; source '$MNT'; [[ \$(_maint_scheduler) == (systemd|launchd|cron) ]]" \
  PATH="$PMBIN"

# ── summary ───────────────────────────────────────────────────────────────────
summary
((FAIL == 0)) || {
  [[ "$NESTED" == 1 ]] || printf '%stests FAILED%s\n' "$c_red" "$c_rst" >&2
  exit 1
}
[[ "$NESTED" == 1 ]] || printf '%stests OK%s\n' "$c_grn" "$c_rst"
