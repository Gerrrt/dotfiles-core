-- ================================================================================================
-- TITLE : nvim-tree.lua | file explorer
-- LINKS : https://github.com/nvim-tree/nvim-tree.lua
-- NOTE  : Lazy-loads on its commands / <leader>e. The toggle keymap (which also closes Zen
--         mode if it's open) used to live in keymaps.lua but couldn't lazy-load the plugin
--         from there — it belongs here.
-- ================================================================================================
return {
	"nvim-tree/nvim-tree.lua",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	cmd = { "NvimTreeToggle", "NvimTreeOpen", "NvimTreeFocus", "NvimTreeFindFile" },
	keys = {
		{
			"<leader>e",
			function()
				local ok, zen = pcall(require, "zen-mode.view")
				if ok and zen.is_open() then
					require("zen-mode").close()
				end
				local api = require("nvim-tree.api")
				if api.tree.is_visible() then
					api.tree.close()
				else
					api.tree.open()
				end
			end,
			desc = "Toggle NvimTree (closes Zen if active)",
		},
	},
	config = function()
		require("nvim-tree").setup({
			filters = { dotfiles = false },
			view = { adaptive_size = false },
		})
	end,
}
