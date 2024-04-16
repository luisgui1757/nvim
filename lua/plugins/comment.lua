return {
  "numToStr/Comment.nvim",
  opts = {},
  lazy = false,

  config = function()
    require("Comment").setup()

    -- Setting up the Ctrl+/ keybinding for toggling comment
    vim.api.nvim_set_keymap("n", "<C-/>", "<Plug>(comment_toggle_linewise_current)", { silent = true })
    vim.api.nvim_set_keymap("x", "<C-/>", "<Plug>(comment_toggle_linewise_visual)", { silent = true })
  end,
}
