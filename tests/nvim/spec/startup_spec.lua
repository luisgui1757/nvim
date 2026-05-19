-- Startup-time regression guard. We invoke nvim a second time as a subprocess
-- so we measure the full --startuptime cost, not just whatever's left after
-- the harness has already initialized.

describe("startup time", function()
	it("init completes under the OS-appropriate budget", function()
		local sysname = (vim.uv.os_uname() or {}).sysname or ""
		-- Linux GitHub Actions runners are slower than local Mac silicon.
		local budget_ms = (sysname == "Darwin") and 200 or 350
		if vim.env.CI == "true" then
			budget_ms = budget_ms + 150 -- account for cold cache + IO contention
		end

		local logfile = vim.fn.tempname()
		local nvim = vim.v.progpath
		local repo_root = _G.TEST_REPO_ROOT

		local out = vim.fn.system({
			nvim, "--headless", "--noplugin",
			"-u", repo_root .. "/tests/nvim/minimal_init.lua",
			"--startuptime", logfile,
			"+qa",
		})
		assert.are.equal(0, vim.v.shell_error, "nvim exited non-zero: " .. tostring(out))

		local fh = assert(io.open(logfile, "r"))
		local total_ms
		for line in fh:lines() do
			local t = line:match("^%s*([%d%.]+)%s")
			if t then total_ms = tonumber(t) end
		end
		fh:close()
		pcall(vim.fn.delete, logfile)

		assert.is_not_nil(total_ms, "could not parse startuptime log")
		assert.is_true(total_ms < budget_ms,
			string.format("startup took %.1fms (budget on %s = %dms)", total_ms, sysname, budget_ms))
	end)
end)
