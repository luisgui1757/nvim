return {
  {
    "tpope/vim-fugitive",
  },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufRead", "BufNewFile" },
    config = function()
      require("gitsigns").setup({
        -- current_line_blame = true,
      })

      vim.keymap.set("n", "<Leader>gp", ":Gitsigns preview_hunk<CR>", { silent = true })
      vim.keymap.set("n", "<Leader>gt", ":Gitsigns toggle_current_line_blame<CR>", { silent = true })
    end,
  },
}
