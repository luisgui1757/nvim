return {
  {
    "numToStr/Comment.nvim",
    opts = {},
    lazy = false,

    config = function()
      require("Comment").setup()

      -- Setting up the Ctrl+/ keybinding for toggling comment
      vim.keymap.set("n", "<C-/>", "<Plug>(comment_toggle_linewise_current)", { silent = true })
      vim.keymap.set("x", "<C-/>", "<Plug>(comment_toggle_linewise_visual)", { silent = true })
    end,
  },
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    event = "BufReadPost",
    config = function()
      require("todo-comments").setup {}
    end,
  },
}
