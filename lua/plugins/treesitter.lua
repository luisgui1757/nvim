return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "c", "cpp", "lua", "python", "markdown" },
        highlight = { enable = true },
        indent = { enable = true },
      })
      vim.api.nvim_del_user_command("EditQuery")
    end,
  },
}
