local function read(path)
  local fh = assert(io.open(path, "r"))
  local s = fh:read("*a")
  fh:close()
  return s
end

describe("DAP config", function()
  local repo_root = _G.TEST_REPO_ROOT

  it("keeps the shared browser launch generic", function()
    local src = read(repo_root .. "/nvim/lua/plugins/debugging.lua")
    assert.is_truthy(src:match("vim%.env%.DAP_LAUNCH_URL"))
    assert.is_truthy(src:match("http://localhost:3000"))
    assert.is_nil(src:match("4504"))
    assert.is_nil(src:match("WM"))
  end)
end)
