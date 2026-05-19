return {
	{
		"numToStr/Comment.nvim",
		keys = {
			{ "gc", mode = { "n", "v" }, desc = "Comment toggle linewise" },
			{ "gcc", mode = "n", desc = "Comment toggle current line" },
			{ "gb", mode = { "n", "v" }, desc = "Comment toggle blockwise" },
			{ "gbc", mode = "n", desc = "Comment toggle current block" },
		},
		config = function()
			require("Comment").setup()
		end,
	},
	{
		"folke/todo-comments.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		event = "BufReadPost",
		config = function()
			require("todo-comments").setup({})
		end,
	},
}
