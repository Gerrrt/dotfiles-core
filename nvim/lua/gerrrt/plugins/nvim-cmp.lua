-- ================================================================================================
-- TITLE : nvim-cmp
-- ABOUT : A completion plugin written in lua.
-- LINKS :
--   > github                             : https://github.com/hrsh7th/nvim-cmp
--   > lspkind (dep)                      : https://github.com/onsails/lspkind.nvim
--   > cmp_luasnip (dep)                  : https://github.com/saadparwaiz1/cmp_luasnip
--   > luasnip (dep)                      : https://github.com/L3MON4D3/LuaSnip
--   > friendly-snippets (dep)            : https://github.com/rafamadriz/friendly-snippets
--   > cmp-nvim-lsp (dep)                 : https://github.com/hrsh7th/cmp-nvim-lsp
--   > cmp-buffer (dep)                   : https://github.com/hrsh7th/cmp-buffer
--   > cmp-path (dep)                     : https://github.com/hrsh7th/cmp-path
--   > cmp-nvim-lsp-signature-help (dep)  : https://github.com/hrsh7th/cmp-nvim-lsp-signature-help
-- ================================================================================================

return {
	"hrsh7th/nvim-cmp",
	dependencies = {
		"onsails/lspkind.nvim",
		"saadparwaiz1/cmp_luasnip",
		{
			"L3MON4D3/LuaSnip",
			version = "v2.*",
			build = "make install_jsregexp",
		},
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
					menu = {
						luasnip = "",
						buffer = "",
						path = "",
						nvim_lsp = "🅻",
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
				{ name = "luasnip" },
				{ name = "nvim_lsp" },
				{ name = "buffer" },
				{ name = "path" },
				{ name = "nvim_lsp_signature_help" },
			},
		})
	end,
}
