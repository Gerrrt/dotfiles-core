-- ================================================================================================
-- TITLE : harpoon (v2) | jump to your pinned files fast
-- LINKS : https://github.com/ThePrimeagen/harpoon/tree/harpoon2
-- ================================================================================================
return {
	"ThePrimeagen/harpoon",
	branch = "harpoon2",
	dependencies = { "nvim-lua/plenary.nvim" },
	config = function()
		local harpoon = require("harpoon")
		harpoon:setup({ settings = { save_on_toggle = true, sync_on_ui_close = true } })

		vim.keymap.set("n", "<leader>ha", function()
			harpoon:list():add()
			vim.notify("Harpoon: added " .. vim.fn.expand("%:t"), vim.log.levels.INFO)
		end, { desc = "Harpoon add file" })
		vim.keymap.set("n", "<leader>hh", function()
			harpoon.ui:toggle_quick_menu(harpoon:list())
		end, { desc = "Harpoon menu" })
		for i = 1, 4 do
			vim.keymap.set("n", "<leader>" .. i, function()
				harpoon:list():select(i)
			end, { desc = "Harpoon file " .. i })
		end
		vim.keymap.set("n", "<leader>hn", function()
			harpoon:list():next()
		end, { desc = "Harpoon next" })
		vim.keymap.set("n", "<leader>hN", function()
			harpoon:list():prev()
		end, { desc = "Harpoon prev" })
	end,
}
