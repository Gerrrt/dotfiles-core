-- ================================================================================================
-- TITLE : nvim-lint | standalone linter runner
-- LINKS : https://github.com/mfussenegger/nvim-lint
-- ABOUT : Runs a filetype's linter on write / leaving insert mode, surfacing results as
--         normal diagnostics (Trouble, <leader>cd, [d/]d all work). Binaries installed by
--         mason-tool-installer in conform.lua.
-- ASTRAL: Python is intentionally NOT here — the ruff language server (servers/ruff.lua)
--         provides Python lint diagnostics AND code actions. Listing ruff here too would
--         double-report.
-- ================================================================================================
return {
	"mfussenegger/nvim-lint",
	event = { "BufReadPost", "BufNewFile" },
	config = function()
		local lint = require("lint")
		lint.linters_by_ft = {
			lua = { "luacheck" },
			sh = { "shellcheck" },
			bash = { "shellcheck" },
			go = { "revive" },
			c = { "cpplint" },
			cpp = { "cpplint" },
			javascript = { "eslint_d" },
			javascriptreact = { "eslint_d" },
			typescript = { "eslint_d" },
			typescriptreact = { "eslint_d" },
			svelte = { "eslint_d" },
			vue = { "eslint_d" },
			dockerfile = { "hadolint" },
			solidity = { "solhint" },
			markdown = { "markdownlint-cli2" }, -- mirrors this repo's markdown gate; formatting stays prettierd (conform)
			yaml = { "yamllint" }, -- schema validation is yamlls' job; yamllint adds style/lint rules
			-- NOTE: no zsh entry. shellcheck only supports sh/bash/dash/ksh and emits SC1071
			-- ("ShellCheck only supports sh/bash/dash/ksh scripts") on a zsh file — i.e. a useless
			-- error diagnostic on every zsh buffer. Nothing reliably lints zsh, so we don't.
		}

		-- ADAPTIVE: eslint_d errors out (and spams a phantom diagnostic on every buffer) when a
		-- JS/TS project has no eslint config in its tree. Mirror the SC1071/ruff guards above by
		-- only linting the eslint family when a config is actually present upward from the buffer.
		local eslint_fts = {
			javascript = true,
			javascriptreact = true,
			typescript = true,
			typescriptreact = true,
			svelte = true,
			vue = true,
		}
		local eslint_cfgs = {
			".eslintrc",
			".eslintrc.js",
			".eslintrc.cjs",
			".eslintrc.json",
			".eslintrc.yaml",
			".eslintrc.yml",
			"eslint.config.js",
			"eslint.config.mjs",
			"eslint.config.cjs",
			"eslint.config.ts",
			"eslint.config.mts",
			"eslint.config.cts",
		}
		local function has_eslint_config()
			return vim.fs.find(eslint_cfgs, {
				upward = true,
				path = vim.fs.dirname(vim.api.nvim_buf_get_name(0)),
				type = "file",
			})[1] ~= nil
		end

		local grp = vim.api.nvim_create_augroup("NvimLint", { clear = true })
		vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
			group = grp,
			callback = function()
				if eslint_fts[vim.bo.filetype] and not has_eslint_config() then
					return -- no eslint config in tree → skip (avoids eslint_d's hard error)
				end
				require("lint").try_lint()
			end,
		})
	end,
}
