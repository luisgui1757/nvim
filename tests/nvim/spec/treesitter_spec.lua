local repo_root = _G.TEST_REPO_ROOT
local fh = assert(io.open(repo_root .. "/nvim/lua/plugins/treesitter.lua", "r"))
local src = fh:read("*a")
fh:close()

describe("treesitter ensure_installed", function()
	local required = {
		"c", "cpp", "cmake", "lua", "python", "rust", "bash", "powershell",
		"json", "jsonc", "yaml", "toml", "markdown", "markdown_inline",
		"vim", "vimdoc", "query", "diff", "gitcommit",
	}
	for _, lang in ipairs(required) do
		it("includes " .. lang, function()
			assert.is_truthy(src:match('"' .. lang .. '"'),
				lang .. " missing from ensure_installed")
		end)
	end

	local forbidden = { "angular", "scss", "csv", "html", "css", "xml", "typescript", "go" }
	for _, lang in ipairs(forbidden) do
		it("does not include " .. lang, function()
			assert.is_nil(src:match('"' .. lang .. '"'),
				lang .. " should be removed from ensure_installed")
		end)
	end

	it("does not force a specific compiler (let TS auto-detect)", function()
		assert.is_nil(src:match("install%.compilers"),
			"don't pin compilers — clang fails on Linux/Windows without it")
	end)

	it("wraps nvim_del_user_command in pcall", function()
		assert.is_truthy(src:match("pcall%(vim%.api%.nvim_del_user_command"),
			"unprotected nvim_del_user_command throws on fresh installs")
	end)
end)
