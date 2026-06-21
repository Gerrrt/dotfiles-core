-- ================================================================================================
-- TITLE : nvim-treesitter-textobjects (main branch) | syntax-aware text objects + motions
-- LINKS : https://github.com/nvim-treesitter/nvim-treesitter-textobjects
-- ABOUT : Gives every language with a parser real function/class/parameter text objects — `vif`
--         (inner function), `dac` (delete a class), `cia` (change inner argument) — plus jumps to
--         the next/previous function. This is the multi-language workhorse mini.ai doesn't cover
--         out of the box; it reads the same treesitter trees you already parse (nvim-treesitter.lua)
--         so it costs no extra parsing.
-- BRANCH: `main` to match your nvim-treesitter `main` spec (the two branches share an API epoch;
--         mixing main + master silently breaks queries).
-- KEYMAPS: deliberately avoids `]c`/`[c` (treesitter-context jump + diff-mode change motions) and
--          `]m`/`[m` to keep your existing nav intact. Movements live on `]f`/`[f` (function) and
--          `]a`/`[a` (argument); text objects on the conventional a*/i*.
-- ================================================================================================
return {
	"nvim-treesitter/nvim-treesitter-textobjects",
	branch = "main",
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	event = { "BufReadPost", "BufNewFile" },
	config = function()
		require("nvim-treesitter-textobjects").setup({
			select = { lookahead = true },
		})

		local select = require("nvim-treesitter-textobjects.select")
		local objects = {
			["af"] = "@function.outer",
			["if"] = "@function.inner",
			["ac"] = "@class.outer",
			["ic"] = "@class.inner",
			["aa"] = "@parameter.outer",
			["ia"] = "@parameter.inner",
		}
		for lhs, query in pairs(objects) do
			vim.keymap.set({ "x", "o" }, lhs, function()
				select.select_textobject(query, "textobjects")
			end, { desc = "Select " .. query })
		end

		local move = require("nvim-treesitter-textobjects.move")
		vim.keymap.set({ "n", "x", "o" }, "]f", function()
			move.goto_next_start("@function.outer", "textobjects")
		end, { desc = "Next function start" })
		vim.keymap.set({ "n", "x", "o" }, "[f", function()
			move.goto_previous_start("@function.outer", "textobjects")
		end, { desc = "Prev function start" })
		vim.keymap.set({ "n", "x", "o" }, "]a", function()
			move.goto_next_start("@parameter.inner", "textobjects")
		end, { desc = "Next argument" })
		vim.keymap.set({ "n", "x", "o" }, "[a", function()
			move.goto_previous_start("@parameter.inner", "textobjects")
		end, { desc = "Prev argument" })
	end,
}
