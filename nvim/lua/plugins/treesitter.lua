return {
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		event = { "BufReadPost", "BufNewFile" },
		config = function()
			require("nvim-treesitter.configs").setup({
				ensure_installed = {
					"c",
					"cpp",
					"cmake",
					"lua",
					"python",
					"rust",
					"bash",
					"powershell",
					"json",
					"jsonc",
					"yaml",
					"toml",
					"markdown",
					"markdown_inline",
					"vim",
					"vimdoc",
					"query",
					"diff",
					"gitcommit",
				},
				highlight = { enable = true, additional_vim_regex_highlighting = false },
				indent = { enable = true },
			})
			-- EditQuery is auto-defined by treesitter on some versions and not
			-- others; deleting unconditionally throws on fresh installs.
			pcall(vim.api.nvim_del_user_command, "EditQuery")
		end,
	},
}
