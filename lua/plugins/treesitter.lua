return {
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		event = { "BufReadPost", "BufNewFile" },
		config = function()
			require("nvim-treesitter.install").compilers = { "clang" }
			require("nvim-treesitter.configs").setup({
				ensure_installed = {
					"c",
					"cpp",
					"lua",
					"python",
					"markdown",
					"cmake",
					"typescript",
					"powershell",
					"html",
					"scss",
					"css",
					"angular",
					"yaml",
					"csv",
					"xml",
					"go",
				},
				highlight = { enable = true },
				indent = { enable = true },
			})
			vim.api.nvim_del_user_command("EditQuery")
		end,
	},
}
