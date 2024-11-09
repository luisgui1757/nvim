return {
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup()
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = {
          "lua_ls",
          "clangd",
          "pyright",
        },
        automatic_installation = true,
      })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    config = function()
      local lspconfig = require("lspconfig")
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      local on_attach = function(client, bufnr)
        if client.server_capabilities.documentFormattingProvider then
          vim.api.nvim_create_autocmd("BufWritePre", {
            buffer = bufnr,
            callback = function()
              vim.lsp.buf.format({ async = false })
            end,
          })
        end
      end

      -- Function to find compile_commands.json
      local function get_compilation_database_path()
        local compile_commands = vim.fn.glob('./o/**/compile_commands.json', true, true)
        if #compile_commands > 0 then
          -- Use the first found compile_commands.json
          return vim.fn.fnamemodify(compile_commands[1], ':h')
        else
          return nil
        end
      end

      local compilation_database_path = get_compilation_database_path()
      local cmd = { "clangd" }
      if compilation_database_path then
        table.insert(cmd, "--compile-commands-dir=" .. compilation_database_path)
      end

      lspconfig.clangd.setup({
        cmd = cmd,
        on_attach = on_attach,
        capabilities = capabilities,
      })

      -- Setup for other language servers
      lspconfig.lua_ls.setup({ on_attach = on_attach, capabilities = capabilities })
      lspconfig.pyright.setup({ on_attach = on_attach, capabilities = capabilities })

      -- Key mappings
      local opts = { noremap = true, silent = true }
      vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
      vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
      vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
      vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
      vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)
      vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)

      -- Diagnostic navigation key mappings
      vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts)
      vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts)
      vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, opts)
      vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, opts)
    end,
  },
}
