local notes_path = ""
local sysname = vim.loop.os_uname().sysname

if sysname == "Darwin" then
  notes_path = "~/Library/Mobile Documents/iCloud~md~obsidian/Documents/luisribeiro"
else
  notes_path = "~/Documents/Notes/luisribeiro"
end

return {
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = function()
      vim.fn["mkdp#util#install"]()
    end,

    vim.api.nvim_set_keymap("n", "<C-s>", "<Plug>MarkdownPreviewToggle", { noremap = true, silent = true })
  },
  {
    "epwalsh/obsidian.nvim",
    version = "*",
    lazy = true,
    ft = "markdown",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    config = function()
      vim.opt.conceallevel = 2
      require("obsidian").setup({

        workspaces = {
          {
            name = "personal",
            path = notes_path,
          },
        },
      })
    end,
  }
}
