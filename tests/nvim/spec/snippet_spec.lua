local repo_root = _G.TEST_REPO_ROOT
local fh = assert(io.open(repo_root .. "/nvim/lua/plugins/completions.lua", "r"))
local src = fh:read("*a")
fh:close()

describe("completion + snippet wiring", function()
  it("declares LuaSnip as a plugin", function()
    assert.is_truthy(src:match('"L3MON4D3/LuaSnip"'))
  end)

  it("declares cmp_luasnip as a plugin", function()
    assert.is_truthy(src:match('"saadparwaiz1/cmp_luasnip"'))
  end)

  it("loads friendly-snippets via dependencies", function()
    assert.is_truthy(src:match('"rafamadriz/friendly%-snippets"'))
  end)

  it("wires cmp.snippet.expand to luasnip.lsp_expand", function()
    assert.is_truthy(
      src:match("luasnip%.lsp_expand%(args%.body%)"),
      "cmp.snippet.expand must call luasnip.lsp_expand for LSP snippets to work"
    )
  end)

  it("registers the luasnip source for cmp", function()
    assert.is_truthy(src:match('name = "luasnip"'), 'cmp sources must include { name = "luasnip" }')
  end)

  it("Tab cycles cmp / luasnip jumps", function()
    assert.is_truthy(src:match('%["<Tab>"%]'), "<Tab> binding for completion/snippet cycling missing")
  end)
end)
