local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- Language Server Protocol (LSP)
require("gerrrt.servers.lua_ls")(capabilities)
require("gerrrt.servers.pyright")(capabilities)
require("gerrrt.servers.gopls")(capabilities)
require("gerrrt.servers.jsonls")(capabilities)
require("gerrrt.servers.ts_ls")(capabilities)
require("gerrrt.servers.bashls")(capabilities)
require("gerrrt.servers.clangd")(capabilities)
require("gerrrt.servers.dockerls")(capabilities)
require("gerrrt.servers.emmet_ls")(capabilities)
require("gerrrt.servers.yamlls")(capabilities)
require("gerrrt.servers.tailwindcss")(capabilities)
require("gerrrt.servers.solidity_ls_nomicfoundation")(capabilities)

-- Linters & Formatters
require("gerrrt.servers.efm-langserver")(capabilities)

vim.lsp.enable({
	"lua_ls",
	"pyright",
	"gopls",
	"jsonls",
	"ts_ls",
	"bashls",
	"clangd",
	"dockerls",
	"emmet_ls",
	"yamlls",
	"tailwindcss",
	"solidity_ls_nomicfoundation",
	"efm",
})

