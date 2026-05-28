-- ================================================================================================
-- TITLE : harpoon (v2)
-- ABOUT : Getting you where you want with the fewest keystrokes
-- LINKS :
--   > github : https://github.com/ThePrimeagen/harpoon/tree/harpoon2
-- ================================================================================================

return {
	"ThePrimeagen/harpoon",
	branch = "harpoon2",
	dependencies = { "nvim-lua/plenary.nvim" },
	config = function()
		local harpoon = require("harpoon")
		harpoon:setup({
			settings = {
				save_on_toggle = true,
				sync_on_ui_close = true,
			},
		})

		-- Add file to harpoon list
		vim.keymap.set("n", "<leader>ha", function()
			harpoon:list():add()
			vim.notify("Harpoon: added " .. vim.fn.expand("%:t"), vim.log.levels.INFO)
		end, { desc = "Harpoon add file" })

		-- Toggle harpoon quick menu
		vim.keymap.set("n", "<leader>hh", function()
			harpoon.ui:toggle_quick_menu(harpoon:list())
		end, { desc = "Harpoon menu" })

		-- Navigate to marks 1–4
		vim.keymap.set("n", "<leader>1", function()
			harpoon:list():select(1)
		end, { desc = "Harpoon file 1" })
		vim.keymap.set("n", "<leader>2", function()
			harpoon:list():select(2)
		end, { desc = "Harpoon file 2" })
		vim.keymap.set("n", "<leader>3", function()
			harpoon:list():select(3)
		end, { desc = "Harpoon file 3" })
		vim.keymap.set("n", "<leader>4", function()
			harpoon:list():select(4)
		end, { desc = "Harpoon file 4" })

		-- Cycle through harpoon list
		vim.keymap.set("n", "<leader>hn", function()
			harpoon:list():next()
		end, { desc = "Harpoon next" })
		vim.keymap.set("n", "<leader>hp", function()
			harpoon:list():prev()
		end, { desc = "Harpoon prev" })
	end,
}
