-- ================================================================================================
-- TITLE : neotest
-- ABOUT : A framework for interacting with tests within Neovim
-- LINKS :
--   > github : https://github.com/nvim-neotest/neotest
-- ================================================================================================

return {
	"nvim-neotest/neotest",
	dependencies = {
		"nvim-neotest/nvim-nio", -- already a dep of nvim-dap-ui
		"nvim-lua/plenary.nvim",
		"antoinemadec/FixCursorHold.nvim",
		"nvim-treesitter/nvim-treesitter",
		-- Adapters
		"rouge8/neotest-rust",
		"nvim-neotest/neotest-python",
		"nvim-neotest/neotest-go",
	},
	config = function()
		local neotest = require("neotest")

		neotest.setup({
			adapters = {
				require("neotest-rust")({
					args = { "--no-capture" },
					dap_adapter = "rt_lldb", -- matches rustaceanvim DAP adapter name
				}),
				require("neotest-python")({
					dap = { justMyCode = false },
					runner = "pytest",
					python = ".venv/bin/python", -- use project venv if present
				}),
				require("neotest-go")({
					args = { "-v", "-count=1" },
				}),
			},

			output = {
				open_on_run = "short",
			},

			summary = {
				open = "botright vsplit | vertical resize 50",
			},

			icons = {
				running_animated = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },
				passed = " ",
				failed = " ",
				skipped = "󰒲 ",
				unknown = " ",
			},
		})

		-- ── Keymaps ─────────────────────────────────────────────────────────────
		vim.keymap.set("n", "<leader>tt", function()
			neotest.run.run()
		end, { desc = "Run nearest test" })

		vim.keymap.set("n", "<leader>tf", function()
			neotest.run.run(vim.fn.expand("%"))
		end, { desc = "Run test file" })

		vim.keymap.set("n", "<leader>ts", function()
			neotest.summary.toggle()
		end, { desc = "Toggle test summary" })

		vim.keymap.set("n", "<leader>to", function()
			neotest.output_panel.toggle()
		end, { desc = "Toggle test output" })

		vim.keymap.set("n", "<leader>tS", function()
			neotest.run.stop()
		end, { desc = "Stop test run" })

		-- Run with DAP debugger attached
		vim.keymap.set("n", "<leader>td", function()
			neotest.run.run({ strategy = "dap" })
		end, { desc = "Debug nearest test" })
	end,
}
