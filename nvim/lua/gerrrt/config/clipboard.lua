-- nvim/lua/gerrrt/config/clipboard.lua
-- ─────────────────────────────────────────────────────────────────────────────
-- Cross-OS system-clipboard provider for Neovim.
--
-- Routes the "+ and "* registers through Core's `clip` / `clip-paste` scripts,
-- which themselves detect WSL / macOS / Wayland / X11. This is what makes
-- `"+y` (yank to system clipboard) and `"+p` (paste from it) work identically on
-- every machine — most importantly on WSL, where Neovim otherwise has NO native
-- clipboard provider and `"+y` silently does nothing.
--
-- Requires `clip` and `clip-paste` on PATH (bootstrap.sh symlinks them into
-- ~/.local/bin). If they're missing, we leave Neovim's own auto-detection alone
-- so nothing breaks on a box that hasn't been bootstrapped.
-- ─────────────────────────────────────────────────────────────────────────────

if vim.fn.executable("clip") == 1 and vim.fn.executable("clip-paste") == 1 then
	vim.g.clipboard = {
		name = "clip-crossos",
		copy = {
			["+"] = "clip",
			["*"] = "clip",
		},
		paste = {
			["+"] = "clip-paste",
			["*"] = "clip-paste",
		},
		-- 0 = always read the clipboard fresh (correct even if you copied from a
		-- Windows/other app). If WSL paste ever feels sluggish, set to 1 to cache
		-- the last in-Neovim yank and skip shelling out for it.
		cache_enabled = 0,
	}
end

-- Optional: route ALL yanks/deletes to the system clipboard automatically.
-- Left off by default so you opt in per-action with the "+ register
-- (e.g. "+yy to copy a line out, "+p to paste from the system clipboard).
-- Uncomment if you'd rather everything sync:
-- vim.opt.clipboard = "unnamedplus"

