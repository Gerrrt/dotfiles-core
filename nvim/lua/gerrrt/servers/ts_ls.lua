return function(capabilities)
	vim.lsp.config("ts_ls", {
		capabilities = capabilities,
		filetypes = { "typescript", "javascript", "typescriptreact", "javascriptreact" },
		settings = { typescript = { indentStyle = "space", indentSize = 2 } },
	})
end
