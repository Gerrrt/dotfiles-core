-- ================================================================================================
-- TITLE : lualine.nvim | statusline
-- LINKS : https://github.com/nvim-lualine/lualine.nvim
-- ABOUT : A polished but restrained statusline:
--           left  : mode · git branch · git diff (+~-)
--           center: filename (relative) with modified/readonly markers
--           right : search count · attached LSP servers · diagnostics · filetype · progress · location
--         Powerline separators need a Nerd Font (you have one). Theme follows tokyonight.
-- ================================================================================================
return {
	"nvim-lualine/lualine.nvim",
	event = "VeryLazy",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		-- Show the language servers attached to the current buffer.
		local function lsp_servers()
			local clients = vim.lsp.get_clients({ bufnr = 0 })
			if #clients == 0 then
				return ""
			end
			local names = {}
			for _, client in ipairs(clients) do
				names[#names + 1] = client.name
			end
			return "  " .. table.concat(names, ", ")
		end

		require("lualine").setup({
			options = {
				theme = "tokyonight",
				icons_enabled = true,
				globalstatus = true,
				section_separators = { left = "", right = "" },
				component_separators = { left = "", right = "" },
				disabled_filetypes = { statusline = { "NvimTree", "neo-tree", "dapui_scopes", "dapui_breakpoints" } },
			},
			sections = {
				lualine_a = {
					{ "mode", icon = "" },
				},
				lualine_b = {
					{ "branch", icon = "" },
					{
						"diff",
						symbols = { added = " ", modified = " ", removed = " " },
					},
				},
				lualine_c = {
					{
						"filename",
						path = 1, -- relative path
						symbols = { modified = "  ●", readonly = "  ", unnamed = "[No Name]" },
					},
				},
				lualine_x = {
					{ "searchcount" },
					{
						lsp_servers,
						color = { gui = "italic" },
					},
					{
						"diagnostics",
						symbols = { error = " ", warn = " ", info = " ", hint = " " },
					},
					{ "filetype" },
				},
				lualine_y = {
					{ "progress" },
				},
				lualine_z = {
					{ "location", icon = "" },
				},
			},
			inactive_sections = {
				lualine_c = { { "filename", path = 1 } },
				lualine_x = { "location" },
			},
			extensions = { "nvim-tree", "lazy", "quickfix", "trouble", "mason" },
		})
	end,
}
