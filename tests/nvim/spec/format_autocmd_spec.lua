-- Regression guard: there must be EXACTLY ONE format-on-save handler.

local function read(path)
  local fh = assert(io.open(path, "r"))
  local s = fh:read("*a")
  fh:close()
  return s
end

local function strip_comments(s)
  s = s:gsub("%-%-%[%[.-%]%]", "")
  s = s:gsub("%-%-[^\n]*", "")
  return s
end

describe("format-on-save autocmds", function()
  local repo_root = _G.TEST_REPO_ROOT

  it("no BufWritePre formatter is registered in lsp-config.lua code", function()
    local code = strip_comments(read(repo_root .. "/nvim/lua/plugins/lsp-config.lua"))
    assert.is_nil(
      code:match("BufWritePre"),
      "lsp-config.lua must not register BufWritePre — that's conform.nvim's job"
    )
    assert.is_nil(code:match('"LspAttach".-vim%.lsp%.buf%.format'), "lsp-config.lua must not auto-format on LspAttach")
  end)

  it("no none-ls.lua exists in plugin tree", function()
    local stat = vim.uv.fs_stat(repo_root .. "/nvim/lua/plugins/none-ls.lua")
    assert.is_nil(stat, "none-ls.lua should be deleted; conform.nvim owns formatting now")
  end)

  it("conform.nvim is registered as the on-save formatter", function()
    local src = read(repo_root .. "/nvim/lua/plugins/conform.lua")
    assert.is_truthy(src:match("format_on_save"))
    assert.is_truthy(
      src:match("skip_format_on_save"),
      "conform.lua must check vim.b.skip_format_on_save for :WNF to work"
    )
  end)

  it("runs Ruff fixes before Ruff formatting for Python", function()
    package.loaded["plugins.conform"] = nil
    local spec = require("plugins.conform")
    assert.are.same({ "ruff_fix", "ruff_format" }, spec.opts.formatters_by_ft.python)
  end)
end)
