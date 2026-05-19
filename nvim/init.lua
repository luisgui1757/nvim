-- Leader must be set BEFORE lazy loads any plugin spec, otherwise
-- every plugin keymap that uses <leader> resolves to '\'.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable",
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

require("vim-options")
require("lazy").setup({
	spec = { { import = "plugins" } },
	change_detection = { notify = false },
	performance = {
		rtp = {
			-- Netrw stays enabled — it provides :Explore, gx URL-opening,
			-- and is what `:E` resolves to.
			disabled_plugins = {
				"gzip",
				"tarPlugin",
				"tohtml",
				"tutor",
				"zipPlugin",
			},
		},
	},
})
