-- ================================================================================================
-- TITLE : mini.nvim modules | small, focused editing upgrades
-- LINKS : https://github.com/echasnovski/mini.nvim
-- NOTE  : Removed mini.comment (Neovim ships native gc/gcc since 0.10) and mini.icons
--         (nvim-web-devicons already covers icons and several plugins depend on it).
--         mini.move owns <A-h/j/k/l> line moving; mini.bufremove backs <leader>bd.
-- ================================================================================================
return {
	{ "echasnovski/mini.ai", version = "*", opts = {} },
	{ "echasnovski/mini.move", version = "*", opts = {} },
	{ "echasnovski/mini.surround", version = "*", opts = {} },
	{ "echasnovski/mini.cursorword", version = "*", opts = {} },
	{ "echasnovski/mini.indentscope", version = "*", opts = {} },
	{ "echasnovski/mini.pairs", version = "*", opts = {} },
	{ "echasnovski/mini.trailspace", version = "*", opts = {} },
	{ "echasnovski/mini.bufremove", version = "*", opts = {} },
	{ "echasnovski/mini.notify", version = "*", opts = {} },
}
