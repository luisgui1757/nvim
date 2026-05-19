package.loaded["util.notes_path"] = nil
local resolve = require("util.notes_path").resolve

local function stub_env(map)
	return function(name)
		local v = map[name]
		if v == nil then return vim.NIL end
		return v
	end
end

describe("notes_path.resolve", function()
	it("Darwin → iCloud Obsidian path", function()
		local p = resolve(function() return { sysname = "Darwin", release = "23.0.0" } end, stub_env({}))
		assert.is_truthy(p:match("Library/Mobile Documents/iCloud~md~obsidian"))
	end)

	it("WSL kernel marker → /mnt/c path with WINUSER", function()
		local p = resolve(
			function() return { sysname = "Linux", release = "5.15.90.1-microsoft-standard-WSL2" } end,
			stub_env({ WINUSER = "alice" })
		)
		assert.are.equal("/mnt/c/Users/alice/OneDrive - Employer/Notes/professional-vault", p)
	end)

	it("native Linux → ~/notes (not the ZF path)", function()
		local p = resolve(function() return { sysname = "Linux", release = "6.5.0-generic" } end, stub_env({}))
		assert.is_truthy(p:match("/notes$"))
		assert.is_nil(p:match("ZF"))
	end)

	it("Windows → USERPROFILE + OneDrive vault", function()
		local p = resolve(
			function() return { sysname = "Windows_NT", release = "10.0" } end,
			stub_env({ USERPROFILE = "C:/Users/bob" })
		)
		assert.is_truthy(p:match("^C:/Users/bob"))
		assert.is_truthy(p:match("OneDrive %- Employer"))
	end)

	it("never throws on missing env vars", function()
		assert.has_no.errors(function()
			-- Use a non-WSL Linux marker so we don't shell out to cmd.exe in CI.
			resolve(function() return { sysname = "Linux", release = "6.5.0" } end, stub_env({}))
		end)
		assert.has_no.errors(function()
			resolve(function() return { sysname = "Windows_NT", release = "10.0" } end, stub_env({}))
		end)
	end)
end)
