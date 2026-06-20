-- ================================================================================================
-- TITLE : rainbow-delimiters.nvim | colour-paired brackets/parens via treesitter
-- LINKS : https://github.com/HiPhish/rainbow-delimiters.nvim
-- ABOUT : Colours matching (), [], {} (and language-specific pairs) by nesting depth so deeply
--         nested code — Lisp-y Lua tables, JSX, Solidity, nested generics — is readable at a
--         glance. Treesitter-driven (so it tracks real syntax, not naive char matching) using the
--         parsers you already install. Complements mini.pairs (which inserts) and the native
--         showmatch/matchparen you have on.
-- LAZY  : event = BufReadPost/BufNewFile, same trigger as treesitter itself.
-- NOTE  : Configured via vim.g.rainbow_delimiters (the plugin's documented entry point) — there is
--         no setup()/opts table, so this uses `config` rather than `opts`.
-- ================================================================================================
return {
	"HiPhish/rainbow-delimiters.nvim",
	event = { "BufReadPost", "BufNewFile" },
	config = function()
		require("rainbow-delimiters.setup").setup({
			strategy = {
				[""] = require("rainbow-delimiters").strategy["global"],
			},
			query = {
				[""] = "rainbow-delimiters",
				lua = "rainbow-blocks", -- also colour do/end, if/end blocks in Lua
			},
		})
	end,
}
