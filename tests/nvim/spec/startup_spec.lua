describe("startup time", function()
  local function mkdir(path)
    vim.fn.mkdir(path, "p")
  end

  local function run_real_init(env, logfile)
    local repo_root = _G.TEST_REPO_ROOT
    local nvim_config = repo_root .. "/nvim"
    local result = vim.system({
      vim.v.progpath,
      "--headless",
      "--cmd",
      "set runtimepath^=" .. vim.fn.fnameescape(nvim_config),
      "-u",
      nvim_config .. "/init.lua",
      "--startuptime",
      logfile,
      "+qa",
    }, {
      env = env,
      text = true,
    }):wait()

    assert.are.equal(
      0,
      result.code,
      table.concat({
        "nvim exited non-zero",
        "stdout: " .. tostring(result.stdout),
        "stderr: " .. tostring(result.stderr),
      }, "\n")
    )
  end

  local function parse_total_ms(logfile)
    local fh = assert(io.open(logfile, "r"))
    local total_ms
    for line in fh:lines() do
      local t = line:match("^%s*([%d%.]+)%s")
      if t then
        total_ms = tonumber(t)
      end
    end
    fh:close()
    return total_ms
  end

  local function lazy_prewarm_path(shared_data, localappdata, sysname)
    if sysname:match("Windows") then
      return localappdata .. "/nvim-data/lazy/lazy.nvim"
    end
    return shared_data .. "/nvim/lazy/lazy.nvim"
  end

  local function mtime_id(path)
    local stat = assert(vim.uv.fs_stat(path), "missing lazy.nvim cache at " .. path)
    local mtime = stat.mtime or {}
    return tostring(mtime.sec) .. ":" .. tostring(mtime.nsec)
  end

  it("real init.lua completes under the OS-appropriate budget", function()
    local sysname = (vim.uv.os_uname() or {}).sysname or ""
    local budget_ms = 1200
    if sysname == "Darwin" then
      budget_ms = 800
    elseif sysname:match("Windows") then
      budget_ms = 2000
    end

    local repo_root = _G.TEST_REPO_ROOT
    local cache_root = repo_root .. "/tests/.cache/startup-real"
    local shared_data = cache_root .. "/data"
    local run_root = cache_root .. "/" .. tostring(vim.uv.hrtime())
    local localappdata = run_root .. "/localappdata"
    local logfile = run_root .. "/startuptime.log"

    mkdir(shared_data)
    mkdir(run_root .. "/config")
    mkdir(run_root .. "/state")
    mkdir(run_root .. "/cache")
    mkdir(run_root .. "/run")
    mkdir(localappdata)
    mkdir(run_root .. "/appdata")
    mkdir(run_root .. "/userprofile")

    local env = {
      XDG_CONFIG_HOME = run_root .. "/config",
      XDG_DATA_HOME = shared_data,
      XDG_STATE_HOME = run_root .. "/state",
      XDG_CACHE_HOME = run_root .. "/cache",
      XDG_RUNTIME_DIR = run_root .. "/run",
      LOCALAPPDATA = localappdata,
      APPDATA = run_root .. "/appdata",
      USERPROFILE = run_root .. "/userprofile",
    }

    assert.are.equal(
      localappdata .. "/nvim-data/lazy/lazy.nvim",
      lazy_prewarm_path(shared_data, localappdata, "Windows_NT")
    )

    local lazy_path = lazy_prewarm_path(shared_data, localappdata, sysname)
    if vim.fn.isdirectory(lazy_path) == 0 then
      run_real_init(env, run_root .. "/prewarm.log")
    end

    local lazy_mtime = mtime_id(lazy_path)
    local skipped_second_prewarm = false
    if vim.fn.isdirectory(lazy_path) == 0 then
      run_real_init(env, run_root .. "/prewarm-second.log")
    else
      skipped_second_prewarm = true
    end
    assert.is_true(skipped_second_prewarm, "lazy prewarm skip path was not exercised")
    assert.are.equal(lazy_mtime, mtime_id(lazy_path), "lazy.nvim cache changed during prewarm skip")

    run_real_init(env, logfile)
    assert.are.equal(lazy_mtime, mtime_id(lazy_path), "startup did not reuse the prewarmed lazy.nvim cache")

    local total_ms = parse_total_ms(logfile)
    pcall(vim.fn.delete, run_root, "rf")

    assert.is_not_nil(total_ms, "could not parse startuptime log")
    assert.is_true(
      total_ms < budget_ms,
      string.format("startup took %.1fms (budget on %s = %dms)", total_ms, sysname, budget_ms)
    )
  end)
end)
