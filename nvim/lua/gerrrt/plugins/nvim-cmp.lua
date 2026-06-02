-- ================================================================================================
-- TITLE : nvim-cmp | completion
-- LINKS : https://github.com/hrsh7th/nvim-cmp
-- NOTE  : Neovim 0.12 has native insert-mode autocomplete now; nvim-cmp is kept because your
--         snippet + lspkind setup is richer. If you ever want to go fully native, this is the
--         file to retire.
-- LAZYDEV: the `lazydev` source (group_index = 0) gives completion for the Neovim lua API and
--         `require` paths when editing your config. group_index 0 puts it in its own priority
--         group so it supersedes the LuaLS source for those completions instead of duplicating.
-- ================================================================================================
return {
	"hrsh7th/nvim-cmp",
	event = "InsertEnter",
	dependencies = {
		"onsails/lspkind.nvim",
		"saadparwaiz1/cmp_luasnip",
		{ "L3MON4D3/LuaSnip", version = "v2.*", build = "make install_jsregexp" },
		"rafamadriz/friendly-snippets",
		"hrsh7th/cmp-nvim-lsp",
		"hrsh7th/cmp-buffer",
		"hrsh7th/cmp-path",
		"hrsh7th/cmp-nvim-lsp-signature-help",
	},
	config = function()
		local lspkind = require("lspkind")
		local cmp = require("cmp")
		local luasnip = require("luasnip")
		require("luasnip.loaders.from_vscode").lazy_load()

		cmp.setup({
			snippet = {
				expand = function(args)
					luasnip.lsp_expand(args.body)
				end,
			},
			formatting = {
				format = lspkind.cmp_format({
					mode = "symbol_text",
					-- Source tags. Written as \u{XXXX} escapes (Nerd Font codepoints), NOT raw glyphs:
					-- raw private-use glyphs get silently stripped in transfer, which is what blanked
					-- luasnip/buffer/path before. Each escape is named — swap any that shows as a box
					-- (tofu) for your font. nvim_lsp's 🅻 (U+1F13B) is normal-plane, so it's safe literal.
					-- To read a glyph's codepoint from your live config: put the cursor on it, press `ga`.
					menu = {
						luasnip = "\u{f121}", -- f121 nf-fa-code   (snippet)
						buffer = "\u{f15b}", -- f15b nf-fa-file   (buffer)
						path = "\u{f07b}", -- f07b nf-fa-folder (path)
						nvim_lsp = "🅻", -- U+1F13B negative squared L (normal plane, survives transfer)
					},
				}),
			},
			mapping = cmp.mapping.preset.insert({
				["<C-k>"] = cmp.mapping.select_prev_item(),
				["<C-j>"] = cmp.mapping.select_next_item(),
				["<C-b>"] = cmp.mapping.scroll_docs(-4),
				["<C-f>"] = cmp.mapping.scroll_docs(4),
				["<C-Space>"] = cmp.mapping.complete(),
				["<C-e>"] = cmp.mapping.abort(),
				["<CR>"] = cmp.mapping.confirm({ select = false }),
			}),
			sources = {
				-- lazydev: Neovim lua API + require-path completion when editing config (lua files).
				-- group_index 0 = its own priority group, so it skips loading LuaLS dupes for these.
				{ name = "lazydev", group_index = 0 },
				{ name = "luasnip" },
				{ name = "nvim_lsp" },
				{ name = "buffer" },
				{ name = "path" },
				{ name = "nvim_lsp_signature_help" },
			},
		})
	end,
}
