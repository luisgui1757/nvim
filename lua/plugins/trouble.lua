return {
  "folke/trouble.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" }, -- Optional: for icons
  opts = {},
  lazy = false,                                     -- Ensure the plugin loads immediately
  config = function()
    require("trouble").setup()

    vim.keymap.set("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", { silent = true, noremap = true })
    vim.keymap.set("n", "<leader>xw", "<cmd>Trouble diagnostics toggle filter.buf=0<cr><cr>",
      { silent = true, noremap = true })

    vim.keymap.set("n", "<leader>cs", "<cmd>Trouble symbols toggle focus=false<cr>", { silent = true, noremap = true })
    vim.keymap.set("n", "<leader>cl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
      { silent = true, noremap = true })
    vim.keymap.set("n", "<leader>xL", "<cmd>Trouble loclist toggle<cr>", { silent = true, noremap = true })
    vim.keymap.set("n", "<leader>xQ", "<cmd>Trouble qflist toggle<cr>", { silent = true, noremap = true })

    vim.keymap.set("n", "gR", "<cmd>Trouble lsp_references toggle<cr>", { silent = true, noremap = true })

    -- Define diagnostic signs
    local signs = {
      Error = " ",
      Warning = " ",
      Hint = " ",
      Information = " ",
    }

    for type, icon in pairs(signs) do
      local hl = "DiagnosticSign" .. type
      vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
    end
  end,
}
