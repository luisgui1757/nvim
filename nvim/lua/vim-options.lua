-- Indentation
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 2

-- Line numbers
vim.opt.number = true
vim.opt.relativenumber = true

-- Modern defaults
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.undofile = true
vim.opt.updatetime = 250
vim.opt.timeoutlen = 400
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.scrolloff = 6
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.confirm = true

-- Mouse intentionally disabled
vim.opt.mouse = ""

-- Whitespace: tab + trailing only (space=· was distracting)
vim.opt.list = true
vim.opt.listchars = { tab = "▸ ", trail = "·", nbsp = "␣" }

-- Cross-platform system clipboard.
-- mac: works via pbcopy; wsl: needs win32yank.exe; linux: needs xclip/wl-copy.
vim.opt.clipboard = "unnamedplus"

-- Disable arrow keys
for _, mode in ipairs({ "n", "i" }) do
	for _, key in ipairs({ "<Up>", "<Down>", "<Left>", "<Right>" }) do
		vim.keymap.set(mode, key, "<Nop>", { noremap = true, silent = true })
	end
end

-- Toggle relative line numbers
vim.keymap.set("n", "<leader>lt", function()
	vim.wo.relativenumber = not vim.wo.relativenumber
end, { noremap = true, silent = true })

-- Clear search highlight
vim.keymap.set("n", "<leader>ch", ":nohlsearch<CR>", { noremap = true, silent = true })

-- Toggle quickfix window
vim.keymap.set("n", "<leader>qq", ":cclose<CR>", { noremap = true, silent = true })

-- Transparent backgrounds for rose-pine over translucent terminals (Ghostty/WT)
vim.api.nvim_create_autocmd("ColorScheme", {
	pattern = "*",
	callback = function()
		vim.cmd("highlight Normal ctermbg=NONE guibg=NONE")
		vim.cmd("highlight NormalNC ctermbg=NONE guibg=NONE")
		vim.cmd("highlight SignColumn ctermbg=NONE guibg=NONE")
		vim.cmd("highlight EndOfBuffer ctermbg=NONE guibg=NONE")
	end,
})

-- Alt-based window navigation
vim.keymap.set("n", "<A-h>", "<C-w>h", { noremap = true, silent = true })
vim.keymap.set("n", "<A-j>", "<C-w>j", { noremap = true, silent = true })
vim.keymap.set("n", "<A-k>", "<C-w>k", { noremap = true, silent = true })
vim.keymap.set("n", "<A-l>", "<C-w>l", { noremap = true, silent = true })

-- :WNF — Write Without Formatting. Sets a buffer-local flag that
-- conform.nvim's format_on_save checks; cleared after the write so
-- the *next* :w formats normally.
vim.api.nvim_create_user_command("WNF", function()
	vim.b.skip_format_on_save = true
	vim.cmd.write()
end, { desc = "Write without running formatters" })
vim.cmd("cnoreabbrev wnf WNF")

vim.api.nvim_create_autocmd("BufWritePost", {
	callback = function(args)
		vim.b[args.buf].skip_format_on_save = nil
	end,
})

-- Drop nvim's default :EditQuery user command. We don't use the
-- treesitter query editor, and keeping it around made :E<Enter>
-- resolve to :EditQuery instead of netrw's :Explore.
pcall(vim.api.nvim_del_user_command, "EditQuery")

-- :E opens netrw at the cwd; :E <path> edits that file/dir.
vim.api.nvim_create_user_command("E", function(opts)
	if opts.args == "" then
		vim.cmd("Explore")
	else
		vim.cmd("edit " .. vim.fn.fnameescape(opts.args))
	end
end, { nargs = "?", complete = "file", desc = "Open netrw, or edit the given file" })
