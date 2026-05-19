-- Regression guard: leader MUST be set before lazy.setup runs, otherwise
-- every `<leader>X` keymap from plugin specs resolves to '\X'.
--
-- The harness sets leader BEFORE require("vim-options") just like the real
-- init.lua does. We verify that order by reading init.lua and asserting
-- the first reference to vim.g.mapleader appears before "lazy").setup".

describe("leader ordering", function()
	it("mapleader assignment precedes lazy.setup in init.lua", function()
		local repo_root = _G.TEST_REPO_ROOT
		assert.is_not_nil(repo_root, "TEST_REPO_ROOT not set by harness")

		local init_path = repo_root .. "/nvim/init.lua"
		local fh = assert(io.open(init_path, "r"))
		local content = fh:read("*a")
		fh:close()

		local leader_pos = content:find("vim%.g%.mapleader")
		local lazy_pos = content:find('require%("lazy"%)%.setup')

		assert.is_not_nil(leader_pos, "vim.g.mapleader assignment missing")
		assert.is_not_nil(lazy_pos, "require('lazy').setup() missing")
		assert.is_true(leader_pos < lazy_pos,
			string.format("mapleader at %d must come BEFORE lazy.setup at %d", leader_pos, lazy_pos))
	end)

	it("mapleader resolves to space at runtime", function()
		assert.are.equal(" ", vim.g.mapleader)
	end)
end)
