# core/zsh/loader.zsh — the canonical zsh module loader (B12).
# ──────────────────────────────────────────────────────────────────────────────
# Every OS repo's .zshrc hand-rolled the SAME byte-compile-then-source loop over the
# Core module list — ~10 lines duplicated across the fleet, the exact drift the Core
# layer exists to kill. This vendors it ONCE. An OS .zshrc now just declares the load
# order and sources this file:
#
#     ZSH_CFG="${ZDOTDIR:-$HOME/.config/zsh}"
#     _CORE_MODULES=(tools ui options history aliases git functions fzf bindings \
#                    plugins op maint update os local)
#     source "$ZSH_CFG/loader.zsh"
#     unset _CORE_MODULES
#
# CRITICAL — this is SOURCED at the caller's scope, NOT wrapped in a function. The
# modules it sources set options (setopt), define aliases, and run compinit; those must
# persist into the interactive shell. A function body with `emulate -L`/LOCAL_OPTIONS
# (as most Core helpers use) would REVERT every option change on return — silently
# breaking the shell. So the loop runs inline, exactly as the old per-repo .zshrc did,
# and the only state it leaves behind is cleaned up below.
#
# Each module is byte-compiled to a .zwc beside its symlink before sourcing: when a fresh
# .zwc exists, `source` loads the wordcode and skips re-parsing — meaningful across ~13
# modules on every shell. The compile only runs when the source is newer than its .zwc
# (or the .zwc is missing), so it self-heals: edit a module (or `git pull`) and the next
# shell recompiles just that file. zcompile is a builtin (no `>` redirection), so
# options.zsh's NO_CLOBBER doesn't apply, and it writes the .zwc atomically. The .zwc
# files land in $ZSH_CFG (the runtime dir), never the repo. `2>/dev/null`: on a read-only
# $ZSH_CFG, compile silently no-ops and we just source the plain script.
# ──────────────────────────────────────────────────────────────────────────────

# Nothing to do unless the caller declared a module list — and never error on a bare
# source (e.g. a unit test that sources every zsh/*.zsh): with no _CORE_MODULES set this
# is a clean no-op, even under `setopt nounset`.
(( ${+_CORE_MODULES} )) || return 0

: "${ZSH_CFG:=${ZDOTDIR:-$HOME/.config/zsh}}"
# Plain (not `local`) vars + an explicit unset at the end: this file is SOURCED at the
# caller's top level, where `local` is an error — mirroring the inline loop it replaces.
for _m in "${_CORE_MODULES[@]}"; do
  _f="$ZSH_CFG/$_m.zsh"
  [[ -r "$_f" ]] || continue
  # NO trailing name arg = script mode: writes "$_f.zwc" (a function-name arg would switch
  # zcompile to digest mode, which `source` can't use as wordcode — keep it single-arg).
  [[ -s "$_f.zwc" && ! "$_f" -nt "$_f.zwc" ]] || zcompile -R -- "$_f" 2>/dev/null
  source "$_f"
done
unset _m _f
