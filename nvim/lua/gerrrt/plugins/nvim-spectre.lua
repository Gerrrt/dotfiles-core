-- nvim/lua/gerrrt/plugins/nvim-spectre.lua
-- nvim-spectre — project-wide search and replace with regex + live preview
-- Complements your existing rg/fzf setup: rg/fzf are for finding,
-- spectre is for mutating results across many files at once.
--
-- Backends: ripgrep (search), sed (replace) — both already in your Brewfile.
--
-- Keys:
--   <leader>S    Toggle Spectre panel
--   <leader>sw   Search current word under cursor
--   <leader>sp   Search in current file only
--   <leader>sc   Spectre: search visually selected text  (visual mode)

return {
	"nvim-pack/nvim-spectre",
	dependencies = { "nvim-lua/plenary.nvim" },
	cmd = { "Spectre" },
	keys = {
		{
			"<leader>S",
			function()
				require("spectre").toggle()
			end,
			desc = "Spectre: toggle panel",
		},
		{
			"<leader>sw",
			function()
				require("spectre").open_visual({ select_word = true })
			end,
			desc = "Spectre: search current word",
		},
		{
			"<leader>sp",
			function()
				require("spectre").open_file_search({ select_word = true })
			end,
			desc = "Spectre: search in current file",
		},
		{
			"<leader>sc",
			function()
				require("spectre").open_visual()
			end,
			mode = "v",
			desc = "Spectre: search visual selection",
		},
	},
	opts = {
		color_devicons = true,
		open_cmd = "vnew",
		live_update = false, -- toggle inside spectre with <leader>tu
		line_sep_start = "┌─────────────────────────────────────────",
		result_padding = "│  ",
		line_sep = "└─────────────────────────────────────────",
		highlight = {
			ui = "String",
			search = "DiffChange",
			replace = "DiffDelete",
		},

		mapping = {
			["toggle_line"] = {
				map = "dd",
				cmd = "<cmd>lua require('spectre').toggle_line()<cr>",
				desc = "Toggle item",
			},
			["enter_file"] = {
				map = "<cr>",
				cmd = "<cmd>lua require('spectre.actions').select_entry()<cr>",
				desc = "Open file",
			},
			["send_to_qf"] = {
				map = "<leader>q",
				cmd = "<cmd>lua require('spectre.actions').send_to_qf()<cr>",
				desc = "Send all items to quickfix",
			},
			["replace_cmd"] = {
				map = "<leader>c",
				cmd = "<cmd>lua require('spectre.actions').replace_cmd()<cr>",
				desc = "Run :substitute on the line",
			},
			["show_option_menu"] = {
				map = "<leader>o",
				cmd = "<cmd>lua require('spectre').show_options()<cr>",
				desc = "Show options menu",
			},
			["run_current_replace"] = {
				map = "<leader>rc",
				cmd = "<cmd>lua require('spectre.actions').run_current_replace()<cr>",
				desc = "Replace current line",
			},
			["run_replace"] = {
				map = "<leader>R",
				cmd = "<cmd>lua require('spectre.actions').run_replace()<cr>",
				desc = "Replace all",
			},
			["change_view_mode"] = {
				map = "<leader>v",
				cmd = "<cmd>lua require('spectre').change_view()<cr>",
				desc = "Change result view mode",
			},
			["change_replace_sed"] = {
				map = "trs",
				cmd = "<cmd>lua require('spectre').change_engine_replace('sed')<cr>",
				desc = "Use sed engine",
			},
			["change_replace_oxi"] = {
				map = "tro",
				cmd = "<cmd>lua require('spectre').change_engine_replace('oxi')<cr>",
				desc = "Use oxi (rust) engine",
			},
			["toggle_live_update"] = {
				map = "tu",
				cmd = "<cmd>lua require('spectre').toggle_live_update()<cr>",
				desc = "Toggle live preview",
			},
			["toggle_ignore_case"] = {
				map = "ti",
				cmd = "<cmd>lua require('spectre').change_options('ignore-case')<cr>",
				desc = "Toggle case sensitivity",
			},
			["toggle_ignore_hidden"] = {
				map = "th",
				cmd = "<cmd>lua require('spectre').change_options('hidden')<cr>",
				desc = "Toggle hidden files",
			},
			["resume_last_search"] = {
				map = "<leader>l",
				cmd = "<cmd>lua require('spectre').resume_last_search()<cr>",
				desc = "Resume previous search",
			},
		},

		find_engine = {
			["rg"] = {
				cmd = "rg",
				args = {
					"--color=never",
					"--no-heading",
					"--with-filename",
					"--line-number",
					"--column",
					"--hidden",
					"--glob=!.git/",
				},
				options = {
					["ignore-case"] = { value = "--ignore-case", icon = "[I]", desc = "ignore case" },
					["hidden"] = { value = "--hidden", icon = "[H]", desc = "hidden files" },
				},
			},
		},

		replace_engine = {
			["sed"] = {
				cmd = "sed",
				-- GNU sed via Homebrew (`brew install gnu-sed`); falls back to BSD sed if missing.
				-- Add `alias sed='gsed'` to your aliases.zsh if you want GNU sed everywhere.
				args = nil,
				options = {
					["ignore-case"] = { value = "--ignore-case", icon = "[I]", desc = "ignore case" },
				},
			},
		},

		default = {
			find = { cmd = "rg", options = { "ignore-case" } },
			replace = { cmd = "sed" },
		},

		replace_vim_cmd = "cdo",
		is_open_target_win = true,
		is_insert_mode = false,
	},
}
