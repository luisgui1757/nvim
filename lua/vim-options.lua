vim.cmd("set expandtab")
vim.cmd("set tabstop=2")
vim.cmd("set softtabstop=2")
vim.cmd("set shiftwidth=2")
vim.cmd("set mouse=")
vim.cmd("set relativenumber")
-- Show whitespace characters
vim.cmd("set listchars=space:·,trail:·")
vim.cmd("set list")

-- Enable Relative Lines
vim.wo.relativenumber = true
-- Show current line as absolute
vim.wo.number = true


-- Disable arrow keys in normal mode
vim.api.nvim_set_keymap("n", "<Up>", "<Nop>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<Down>", "<Nop>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<Left>", "<Nop>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<Right>", "<Nop>", { noremap = true, silent = true })

-- Disable arrow keys in insert mode
vim.api.nvim_set_keymap("i", "<Up>", "<Nop>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("i", "<Down>", "<Nop>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("i", "<Left>", "<Nop>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("i", "<Right>", "<Nop>", { noremap = true, silent = true })

vim.api.nvim_set_option("clipboard", "unnamed")

vim.g.mapleader = " "

-- Define a Lua function to toggle between relative and absolute line numbers
function toggle_line_numbers()
  -- Check if relative line numbers are currently enabled
  if vim.wo.relativenumber then
    -- Turn off relative numbers, turn on absolute numbers
    vim.wo.relativenumber = false
    vim.wo.number = true
  else
    -- Turn on relative numbers, absolute numbers will also be on
    vim.wo.relativenumber = true
    vim.wo.number = true
  end
end

-- Define a Lua function to clear the background
local function clear_background()
  vim.api.nvim_command("highlight Normal ctermbg=NONE guibg=NONE")
end

-- Lua function to clear the search highlight
function clear_search_highlight()
  vim.api.nvim_exec("nohlsearch", false)
end

-- Create an autocmd group and set up the autocmd
vim.api.nvim_create_augroup("user_colors", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", {
  group = "user_colors",
  pattern = "*",
  callback = clear_background,
})

-- Creating a command that references the local function
vim.cmd([[command! ToggleLineNumbers lua toggle_line_numbers()]])
vim.api.nvim_set_keymap('n', '<leader>lt', '<cmd>ToggleLineNumbers<CR>', { noremap = true, silent = true })

-- Mapping the key combination to the Lua function
vim.api.nvim_set_keymap('n', '<leader>ch', '<cmd>lua clear_search_highlight()<CR>', { noremap = true, silent = true })


