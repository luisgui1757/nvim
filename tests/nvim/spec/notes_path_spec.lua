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
	it("NOTES_VAULT override wins on any OS", function()
		local p = resolve(
			function() return { sysname = "Darwin", release = "23.0.0" } end,
			stub_env({ NOTES_VAULT = "/some/custom/vault" })
		)
		assert.are.equal("/some/custom/vault", p)
	end)

	it("Darwin → iCloud Obsidian root (no user/vault name baked in)", function()
		local p = resolve(function() return { sysname = "Darwin", release = "23.0.0" } end, stub_env({}))
		assert.is_truthy(p:match("Library/Mobile Documents/iCloud~md~obsidian/Documents$"))
	end)

	it("WSL kernel marker → generic /mnt/c/Users/<winuser>/Notes", function()
		local p = resolve(
			function() return { sysname = "Linux", release = "5.15.90.1-microsoft-standard-WSL2" } end,
			stub_env({ WINUSER = "alice" })
		)
		assert.are.equal("/mnt/c/Users/alice/Notes", p)
		assert.is_nil(p:match("ZF"))
	end)

	it("native Linux → ~/notes", function()
		local p = resolve(function() return { sysname = "Linux", release = "6.5.0-generic" } end, stub_env({}))
		assert.is_truthy(p:match("/notes$"))
		assert.is_nil(p:match("ZF"))
	end)

	it("Windows → generic USERPROFILE/Notes (no employer vault)", function()
		local p = resolve(
			function() return { sysname = "Windows_NT", release = "10.0" } end,
			stub_env({ USERPROFILE = "C:/Users/bob" })
		)
		assert.are.equal("C:/Users/bob/Notes", p)
		assert.is_nil(p:match("ZF"))
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
