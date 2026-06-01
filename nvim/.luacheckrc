-- ================================================================================================
-- .luacheckrc — Luacheck configuration for this Neovim config
-- Lives at the config root so luacheck (run by nvim-lint on lua files) discovers it by
-- searching upward. This is what stops the false "accessing undefined variable vim" warnings.
-- ================================================================================================

-- Neovim embeds LuaJIT
std = "luajit"

cache = true

-- Neovim injects `vim` as a global; allow reading and writing vim.* fields.
globals = { "vim" }

-- Let stylua / your colorcolumn own line width — don't double-warn on it.
max_line_length = false

ignore = {
	"212", -- unused argument (very common in callbacks like on_attach(event))
}
