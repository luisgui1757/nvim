local notes_path = require("util.notes_path").resolve()

-- markdown-preview.nvim removed deliberately. Its `cd app && npm install`
-- build step modifies app/yarn.lock inside the plugin clone, which then
-- permanently breaks `:Lazy update markdown-preview.nvim` ("You have local
-- changes ... please remove them to update"). render-markdown.nvim (see
-- markdown.lua) provides inline preview, and obsidian.nvim handles the
-- vault workflow -- a browser preview window isn't worth this maintenance
-- cost. If you ever need it again, see `previm/previm` (no build step) or
-- the precompiled `cd app && npx --yes yarn install --frozen-lockfile`
-- variant of the original.

return {
  {
    "epwalsh/obsidian.nvim",
    ft = { "markdown" },
    dependencies = { "nvim-lua/plenary.nvim" },
    -- NOTE: previously gated behind `enabled = isdirectory(notes_path)`,
    -- which silently disabled obsidian on any machine whose vault dir didn't
    -- exist yet (e.g. the generic ~/notes fallback). We now always load it on
    -- markdown filetypes and create the vault dir below, so it's actually
    -- there. Point it at YOUR vault by exporting NOTES_VAULT (e.g. in a
    -- gitignored ~/.zshrc.local); otherwise an OS-appropriate default is used
    -- (see util/notes_path.lua).
    config = function()
      pcall(vim.fn.mkdir, notes_path, "p") -- never let a mkdir failure break startup
      require("obsidian").setup({
        workspaces = {
          { name = "notes", path = notes_path },
        },
        -- Obsidian's own UI stays disabled; render-markdown.nvim owns
        -- rendering everywhere (markdown.lua + CLAUDE.md invariant #11).
        ui = { enable = false },
      })
    end,
  },
}
