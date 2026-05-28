return {
  {
    "nvim-treesitter/nvim-treesitter",
    -- Pin to master, NOT main. The upstream default flipped from
    -- master to main in late 2024, and main is a complete API
    -- rewrite that removed `require("nvim-treesitter.configs").setup`
    -- (the module is gone). master keeps the legacy API and is still
    -- maintained for backports. Lazy.nvim follows the default branch
    -- unless we pin, so without this users get the new API and a
    -- "module 'nvim-treesitter.configs' not found" crash on first
    -- BufReadPost.
    branch = "master",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "c",
          "cpp",
          "cmake",
          "lua",
          "python",
          "rust",
          "bash",
          "powershell",
          "json",
          "jsonc",
          "yaml",
          "toml",
          "markdown",
          "markdown_inline",
          "vim",
          "vimdoc",
          "query",
          "diff",
          "gitcommit",
        },
        highlight = { enable = true, additional_vim_regex_highlighting = false },
        indent = { enable = true },
      })
      -- EditQuery is auto-defined by treesitter on some versions and not
      -- others; deleting unconditionally throws on fresh installs.
      pcall(vim.api.nvim_del_user_command, "EditQuery")
    end,
  },
}
