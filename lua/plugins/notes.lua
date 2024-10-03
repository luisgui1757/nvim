local notes_path = vim.fn.expand("~")

if vim.loop.os_uname().sysname == "Darwin" then
  notes_path = notes_path .. "/Library/Mobile Documents/iCloud~md~obsidian/Documents/luisribeiro"
else
  notes_path = notes_path .. "/Documents/Notes/luisribeiro"
end

return {
  {
    "iamcco/markdown-preview.nvim",
    ft = { "markdown" },
    build = "cd app && npm install",
    config = function()
      vim.keymap.set("n", "<C-s>", "<Plug>MarkdownPreviewToggle", { noremap = true, silent = true })
    end,
  },
  {
    "epwalsh/obsidian.nvim",
    ft = { "markdown" },
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      vim.opt.conceallevel = 2
      require("obsidian").setup({
        dir = notes_path,
      })
    end,
  },
}
