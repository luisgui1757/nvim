local notes_path = vim.fn.expand("~")
if vim.loop.os_uname().sysname == "Darwin" then
	notes_path = notes_path .. "/Library/Mobile Documents/iCloud~md~obsidian/Documents/user"
else
	notes_path = notes_path .. "/OneDrive - Employer/Notes/professional-vault"
end

return {
	{
		"iamcco/markdown-preview.nvim",
		ft = { "markdown" },
		build = "cd app && npm install",
		config = function()
			vim.keymap.set("n", "<C-s>", "<Plug>MarkdownPreviewToggle")
		end,
	},
	{
		"epwalsh/obsidian.nvim",
		ft = { "markdown" },
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			require("obsidian").setup({
				workspaces = {
					{
						name = "work",
						path = notes_path,
					},
				},
				ui = {
					enable = false,
				},
			})
		end,
	},
}
