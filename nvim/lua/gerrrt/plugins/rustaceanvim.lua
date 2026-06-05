-- ================================================================================================
-- TITLE : rustaceanvim | batteries-included Rust (LSP + DAP via rust-analyzer)
-- LINKS : https://github.com/mrcjkb/rustaceanvim
-- ================================================================================================
-- NOTE: no on_attach is passed to rustaceanvim's server below. Buffer-local LSP keymaps
-- (K, gd, gr, <leader>ca, ...) are applied globally by the LspAttach autocmd in
-- config/autocmds.lua, which fires for rust-analyzer like every other server — so Rust gets
-- the same maps for free. (Passing utils/lsp.on_attach here used to be a no-op: rustaceanvim
-- calls server.on_attach with the classic (client, bufnr) signature, but that function expects
-- an LspAttach *event* table and early-returns on anything else.)
local config = function()
	vim.g.rustaceanvim = {
		tools = { hover_actions = { auto_focus = true } },
		server = {
			default_settings = {
				["rust-analyzer"] = { cargo = { allFeatures = true } },
			},
		},
		dap = {
			adapter = {
				type = "executable",
				command = vim.fn.exepath("lldb-dap") ~= "" and "lldb-dap"
					or vim.fn.trim(vim.fn.system("xcrun -f lldb-dap")),
				name = "rt_lldb",
			},
		},
	}
end

return {
	"mrcjkb/rustaceanvim",
	version = "^6",
	ft = "rust",
	config = config,
}
