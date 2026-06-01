return function(capabilities)
	vim.lsp.config("emmet_ls", {
		capabilities = capabilities,
		filetypes = {
			"typescript",
			"javascript",
			"javascriptreact",
			"typescriptreact",
			"css",
			"sass",
			"scss",
			"svelte",
			"vue",
		},
	})
end
