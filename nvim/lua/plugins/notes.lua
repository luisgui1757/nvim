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
		enabled = function()
			return vim.fn.isdirectory(notes_path) == 1
		end,
		config = function()
			require("obsidian").setup({
				workspaces = {
					{ name = "work", path = notes_path },
				},
				ui = { enable = false },
			})
		end,
	},
}
