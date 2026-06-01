return function(capabilities)
	vim.lsp.config("solidity", {
		capabilities = capabilities,
		single_file_support = true,
		cmd = { "nomicfoundation-solidity-language-server", "--stdio" },
		filetypes = { "solidity" },
		settings = { rootMarkers = { ".git/" } },
	})
end
