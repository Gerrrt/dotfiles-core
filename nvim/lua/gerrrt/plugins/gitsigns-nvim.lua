-- ================================================================================================
-- TITLE : gitsigns.nvim | git hunks in the gutter
-- LINKS : https://github.com/lewis6991/gitsigns.nvim
-- ================================================================================================
return {
	"lewis6991/gitsigns.nvim",
	event = { "BufReadPre", "BufNewFile" },
	opts = {
		on_attach = function(bufnr)
			local gs = require("gitsigns")
			local function map(mode, l, r, desc)
				vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
			end
			map("n", "]h", function()
				gs.nav_hunk("next")
			end, "Next git hunk")
			map("n", "[h", function()
				gs.nav_hunk("prev")
			end, "Prev git hunk")
			map("n", "<leader>gs", gs.stage_hunk, "Stage hunk")
			map("n", "<leader>gr", gs.reset_hunk, "Reset hunk")
			map("n", "<leader>gp", gs.preview_hunk, "Preview hunk")
			map("n", "<leader>gb", function()
				gs.blame_line({ full = true })
			end, "Blame line")
			map("n", "<leader>gd", gs.diffthis, "Diff this")
			map("n", "<leader>gu", gs.undo_stage_hunk, "Undo stage hunk")
		end,
	},
}
