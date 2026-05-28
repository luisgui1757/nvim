local repo_root = _G.TEST_REPO_ROOT
local fh = assert(io.open(repo_root .. "/nvim/lua/plugins/markdown.lua", "r"))
local src = fh:read("*a")
fh:close()

describe("markdown rendering plugin", function()
  it("declares render-markdown.nvim", function()
    assert.is_truthy(src:match('"MeanderingProgrammer/render%-markdown%.nvim"'))
  end)

  it("lazy-loads on markdown ft only", function()
    assert.is_truthy(src:match('ft = { "markdown"'), "render-markdown should only load when entering a markdown buffer")
  end)

  it("enables task-list checkbox rendering", function()
    assert.is_truthy(src:match("checkbox = {"), "checkbox config block missing")
    assert.is_truthy(src:match("unchecked = {"), "unchecked checkbox icon config missing")
    assert.is_truthy(src:match("checked%s+= {"), "checked checkbox icon config missing")
  end)

  it("enables Obsidian-style callouts ([!NOTE], [!WARNING], etc.)", function()
    assert.is_truthy(src:match("%[!NOTE%]"))
    assert.is_truthy(src:match("%[!WARNING%]"))
  end)

  it("uses Rose Pine palette for heading colors", function()
    assert.is_truthy(src:match("#c4a7e7"), "iris (rose-pine) missing from heading config")
    assert.is_truthy(src:match("#9ccfd8"), "foam (rose-pine) missing")
  end)
end)
