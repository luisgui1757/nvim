return {
  {
    "tpope/vim-fugitive",
    cmd = { "G", "Git", "Gdiffsplit", "Gread", "Gwrite", "Ggrep", "GMove", "GDelete", "GBrowse" },
  },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "" },
        topdelete = { text = "" },
        changedelete = { text = "▎" },
        untracked = { text = "▎" },
      },
    },
    config = function(_, opts)
      require("gitsigns").setup(opts)
      vim.keymap.set("n", "<leader>gp", ":Gitsigns preview_hunk<CR>", { silent = true, desc = "Preview hunk" })
      vim.keymap.set(
        "n",
        "<leader>gt",
        ":Gitsigns toggle_current_line_blame<CR>",
        { silent = true, desc = "Toggle line blame" }
      )
      vim.keymap.set("n", "]h", ":Gitsigns next_hunk<CR>", { silent = true, desc = "Next hunk" })
      vim.keymap.set("n", "[h", ":Gitsigns prev_hunk<CR>", { silent = true, desc = "Prev hunk" })
    end,
  },
}
