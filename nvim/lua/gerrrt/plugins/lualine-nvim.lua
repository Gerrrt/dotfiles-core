-- ================================================================================================
-- TITLE : lualine.nvim
-- LINKS :
--   > github : https://github.com/nvim-lualine/lualine.nvim
-- ABOUT : A blazing fast and easy to configure Neovim statusline written in Lua.
-- ================================================================================================

return {
	"nvim-lualine/lualine.nvim",
	config = function()
		require("lualine").setup({
			options = {
				-- theme = "melange",
				theme = "tokyonight",
				icons_enabled = true,
				globalstatus = true,
			},
		})
	end,
	dependencies = { "nvim-tree/nvim-web-devicons" },
}
