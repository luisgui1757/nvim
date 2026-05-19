local notes_path = require("util.notes_path").resolve()

return {
	{
		"iamcco/markdown-preview.nvim",
		ft = { "markdown" },
		build = "cd app && npm install",
		keys = {
			{ "<leader>mp", "<Plug>MarkdownPreviewToggle", ft = "markdown", desc = "Toggle markdown preview" },
		},
	},
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
