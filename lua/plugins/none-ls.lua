return {
  "nvimtools/none-ls.nvim",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    -- Prevent all autoformatters from running on save
    local augroup = vim.api.nvim_create_augroup("NullLsFormatting", {})
    local null_ls = require("null-ls")

    local function on_attach(client, bufnr)
      if client.supports_method("textDocument/formatting") then
        vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
        vim.api.nvim_create_autocmd("BufWritePre", {
          group = augroup,
          buffer = bufnr,
          callback = function()
            vim.lsp.buf.format({ async = false })
          end,
        })
      end
    end

    null_ls.setup({
      sources = {
        null_ls.builtins.formatting.cmake_format,
        null_ls.builtins.formatting.gersemi.with({
          extra_args = {
            "--line-length", "120",
            "--indent", "2",
          },
        }),
      },
      on_attach = on_attach,
    })

    vim.keymap.set("n", "<leader>gf", vim.lsp.buf.format, {})
  end,
}
