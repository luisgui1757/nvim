-- Read the LSP plugin spec and assert all expected servers are configured.

local repo_root = _G.TEST_REPO_ROOT
local fh = assert(io.open(repo_root .. "/nvim/lua/plugins/lsp-config.lua", "r"))
local src = fh:read("*a")
fh:close()

-- Strip Lua comments so test patterns don't false-positive on comment text
-- like "-- don't add a BufWritePre formatter here".
local function strip_comments(s)
	-- block comments first
	s = s:gsub("%-%-%[%[.-%]%]", "")
	-- line comments
	s = s:gsub("%-%-[^\n]*", "")
	return s
end
local code_only = strip_comments(src)

describe("LSP server coverage", function()
	local required_servers = {
		"clangd",
		"lua_ls",
		"pyright",
		"rust_analyzer",
		"bashls",
		"yamlls",
		"jsonls",
		"neocmake",
		"powershell_es",
	}

	for _, server in ipairs(required_servers) do
		it("configures " .. server, function()
			local pattern = 'vim%.lsp%.config%("' .. server .. '"'
			assert.is_truthy(code_only:match(pattern),
				'vim.lsp.config("' .. server .. '", ...) not found in lsp-config.lua')
		end)
		it("enables " .. server, function()
			local pattern = '"' .. server .. '"'
			local enable_block = code_only:match("vim%.lsp%.enable%({(.-)}%)")
			assert.is_not_nil(enable_block, "vim.lsp.enable({...}) block missing")
			assert.is_truthy(enable_block:find(pattern, 1, true),
				server .. " not in vim.lsp.enable list")
		end)
	end

	it("uses :supports_method (colon syntax) not dot syntax", function()
		assert.is_nil(code_only:match("client%.supports_method"),
			"client.supports_method (dot) is deprecated; use client:supports_method (colon)")
	end)

	it("does not register a BufWritePre formatter on LspAttach", function()
		assert.is_nil(code_only:match("BufWritePre"),
			"format-on-save belongs in conform.nvim, not here")
	end)

	-- setup.{sh,ps1} run `nvim --headless +MasonToolsInstallSync` (phase 4) and
	-- CLAUDE.md runs `+MasonToolsUpdate`. mason-tool-installer is event=VeryLazy,
	-- which never fires without a UI, so each command MUST also be a lazy `cmd`
	-- load-trigger or the headless invocation dies with "E492: Not an editor
	-- command". Regression guard for exactly that.
	for _, mcmd in ipairs({ "MasonToolsInstallSync", "MasonToolsUpdate" }) do
		it("registers " .. mcmd .. " as a cmd load-trigger (headless setup phase)", function()
			assert.is_truthy(code_only:find(mcmd, 1, true),
				mcmd .. " is not a cmd trigger in lsp-config.lua; headless `nvim +"
					.. mcmd .. "` would fail with E492")
		end)
	end
end)
