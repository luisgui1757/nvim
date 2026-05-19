describe("vim-options", function()
	it("sets cross-platform clipboard to unnamedplus", function()
		assert.is_true(vim.tbl_contains(vim.opt.clipboard:get(), "unnamedplus"))
	end)

	it("enables termguicolors", function()
		assert.is_true(vim.opt.termguicolors:get())
	end)

	it("forces signcolumn = yes", function()
		assert.are.equal("yes", vim.opt.signcolumn:get())
	end)

	it("enables undofile", function()
		assert.is_true(vim.opt.undofile:get())
	end)

	it("has snappy updatetime + timeoutlen", function()
		assert.is_true(vim.opt.updatetime:get() <= 250)
		assert.is_true(vim.opt.timeoutlen:get() <= 400)
	end)

	it("listchars use tab/trail/nbsp (NOT space=·)", function()
		local lc = vim.opt.listchars:get()
		assert.is_not_nil(lc.tab)
		assert.is_not_nil(lc.trail)
		assert.is_not_nil(lc.nbsp)
		assert.is_nil(lc.space) -- regression guard
	end)

	it("smartcase + ignorecase both enabled", function()
		assert.is_true(vim.opt.ignorecase:get())
		assert.is_true(vim.opt.smartcase:get())
	end)

	it("mapleader is space", function()
		assert.are.equal(" ", vim.g.mapleader)
	end)

	it(":EditQuery is overridden with a parser-aware safe variant", function()
		local cmds = vim.api.nvim_get_commands({})
		assert.is_not_nil(cmds.EditQuery, ":EditQuery user command is missing")
		assert.is_truthy((cmds.EditQuery.definition or ""):match("parser") or
			(cmds.EditQuery.description or ""):lower():match("parser"),
			":EditQuery override should be the safe variant (description mentions parser handling)")
	end)

	it(":EditQuery does not crash on a parser-less [No Name] buffer", function()
		-- The whole point of the override: the bare nvim default asserts and
		-- prints a stack trace on a fresh buffer with no filetype/parser.
		local ok, err = pcall(vim.cmd, "EditQuery")
		assert.is_true(ok, ":EditQuery should never throw — got: " .. tostring(err))
	end)
end)
