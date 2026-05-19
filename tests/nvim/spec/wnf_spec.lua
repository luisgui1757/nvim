describe(":WNF (Write Without Formatting)", function()
	local tmpfile

	before_each(function()
		tmpfile = vim.fn.tempname() .. ".py"
		vim.cmd("edit " .. tmpfile)
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { "def  f( ):pass" })
	end)

	after_each(function()
		pcall(vim.fn.delete, tmpfile)
	end)

	it("is registered as a user command and via :wnf abbrev", function()
		local cmds = vim.api.nvim_get_commands({})
		assert.is_not_nil(cmds.WNF, ":WNF command not defined")

		local abbrev_out = vim.fn.execute("cabbrev wnf")
		assert.is_truthy(abbrev_out:match("WNF"), ":wnf abbrev not registered")
	end)

	it("sets vim.b.skip_format_on_save before writing", function()
		-- Stash a marker that proves the flag was set during the write
		local saw_skip = false
		vim.api.nvim_create_autocmd("BufWritePre", {
			buffer = 0,
			once = true,
			callback = function()
				if vim.b.skip_format_on_save then saw_skip = true end
			end,
		})
		vim.cmd("WNF")
		assert.is_true(saw_skip, "BufWritePre fired without skip_format_on_save flag set")
	end)

	it("clears the flag after BufWritePost", function()
		vim.cmd("WNF")
		-- BufWritePost is synchronous in headless mode, so the autocmd has fired.
		assert.is_nil(vim.b.skip_format_on_save, "skip_format_on_save flag was not cleared")
	end)

	it("writes the buffer content unchanged to disk", function()
		vim.cmd("WNF")
		local on_disk = vim.fn.readfile(tmpfile)
		assert.are.same({ "def  f( ):pass" }, on_disk)
	end)
end)
