-- ================================================================================================
-- TITLE : tokyonight-nvim
-- ABOUT : A clean Neovim theme written in Lua, celebrating the lights of a futuristic Tokyo.
-- LINKS :
--   > github : https://github.com/folke/tokyonight.nvim
-- ================================================================================================

return {
	{
		"xiyaowong/nvim-transparent",
		lazy = false,
		priority = 999,
		opts = {
			extra_groups = {
				"NvimTreeNormal",
				"NvimTreeNormalNC",
				"NvimTreeSignColumn",
				"NvimTreeEndOfBuffer",
				"NvimTreeWinSeparator",
			},
		},
	},

	{
		"folke/tokyonight.nvim",
		lazy = false,
		priority = 999,
		config = function()
			require("tokyonight").setup({
				style = "storm", -- Options: storm, moon, night, day
				transparent = false, -- Enables transparency for background elements
				styles = {
					sidebars = "normal", -- Ensures file trees stay transparent
					floats = "normal", -- Ensures floating windows stay transparent
				},
				on_highlights = function(hl, c)
					-- Example: Make visual selections pop out more using the theme's palette
					hl.Visual = { bg = c.bg_visual }
					-- Example: Force comments to be italicized
					hl.Comment = { fg = c.comment, italic = true }
				end,
			})
			vim.cmd("colorscheme tokyonight")
		end,
	},
}
