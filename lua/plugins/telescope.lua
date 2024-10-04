return {
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.6",
    cmd = "Telescope",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local builtin = require("telescope.builtin")
      vim.keymap.set("n", "<C-p>", builtin.find_files, { noremap = true, silent = true })
      vim.keymap.set("n", "<leader>fg", builtin.live_grep, { noremap = true, silent = true })
    end,
  },
  {
    "nvim-telescope/telescope-ui-select.nvim",
    after = "telescope.nvim",
    config = function()
      require("telescope").load_extension("ui-select")
    end,
  },
}
