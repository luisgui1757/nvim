return {
  -- Completion sources
  { "hrsh7th/cmp-nvim-lsp", event = "InsertEnter" },
  { "hrsh7th/cmp-buffer",   event = "InsertEnter" },
  { "hrsh7th/cmp-path",     event = "InsertEnter" },
  { "hrsh7th/cmp-cmdline",  event = "CmdlineEnter" },

  -- LuaSnip for snippet support
  {
    "L3MON4D3/LuaSnip",
    event = "InsertCharPre",
    dependencies = {
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
    },
  },

  -- nvim-cmp for auto-completion
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    config = function()
      local cmp = require("cmp")
      cmp.setup({
        snippet = {
          expand = function(args)
            require("luasnip").lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "copilot" }, -- Added Copilot source
          { name = "luasnip" },
        }, {
          { name = "buffer" },
        }),
      })
    end,
  },

  -- nvim-autopairs for automatic pairing of brackets, quotes, etc.
  -- {
  --   "windwp/nvim-autopairs",
  --   config = function()
  --     require("nvim-autopairs").setup()
  --   end,
  -- },

  -- vim-surround for easy manipulation of surrounding characters
  -- {
  --   "tpope/vim-surround",
  -- },
}
