return {
  {
    "mbbill/undotree",
    cmd = "UndotreeToggle",
    config = function()
      vim.keymap.set("n", "<leader>u", ":UndotreeToggle<CR>", { noremap = true, silent = true })
    end,
  },
}
