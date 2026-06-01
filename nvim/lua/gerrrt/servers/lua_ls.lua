return function(capabilities)
	vim.lsp.config("lua_ls", {
		capabilities = capabilities,
		settings = {
			Lua = {
				diagnostics = { globals = { "vim" } },
				workspace = {
					library = {
						vim.fn.expand("$VIMRUNTIME/lua"),
						-- stdpath("config") resolves to ~/.config/nvim even when
						-- $XDG_CONFIG_HOME isn't exported (common), so lua_ls reliably
						-- indexes your own gerrrt.* modules for completion.
						vim.fn.stdpath("config") .. "/lua",
					},
				},
			},
		},
	})
end
