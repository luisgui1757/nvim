-- Indentation settings
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 2

-- Line numbers
vim.opt.number = true
vim.opt.relativenumber = true

-- Disable mouse support
vim.opt.mouse = ""

-- Show whitespace characters
vim.opt.list = true
vim.opt.listchars = { space = "·", trail = "·" }

-- Disable arrow keys
for _, mode in ipairs({ "n", "i" }) do
  for _, key in ipairs({ "<Up>", "<Down>", "<Left>", "<Right>" }) do
    vim.keymap.set(mode, key, "<Nop>", { noremap = true, silent = true })
  end
end

-- Clipboard
vim.opt.clipboard = "unnamed"

-- Leader key
vim.g.mapleader = " "

-- Toggle relative line numbers
vim.keymap.set("n", "<leader>lt", function()
  vim.wo.relativenumber = not vim.wo.relativenumber
end, { noremap = true, silent = true })

-- Clear search highlight
vim.keymap.set("n", "<leader>ch", ":nohlsearch<CR>", { noremap = true, silent = true })

-- Clear background on colorscheme change
vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "*",
  callback = function()
    vim.cmd("highlight Normal ctermbg=NONE guibg=NONE")
  end,
})
