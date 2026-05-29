-- Minimal nvim init for the plenary busted suite.
--
-- Two execution contexts:
--   1. Parent (`PlenaryBustedDirectory`) — uses this to discover & schedule.
--   2. Subprocess per spec file — re-runs this so each spec gets a clean nvim.
--
-- Goals:
--   * Make the repo's `nvim/lua/...` requireable as if it were $XDG_CONFIG_HOME/nvim.
--   * Install + register plenary so PlenaryBustedDirectory/Plenary's busted exist.
--   * Set the same options/keymaps/commands that `nvim/init.lua` sets, so
--     tests that ask "is vim.g.mapleader space?" see the production state.

local function script_path()
  -- debug.getinfo(1, "S").source is "@/abs/or/relative/path"
  local src = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.resolve(vim.fn.fnamemodify(src, ":p"))
end

local this_file = script_path()
local repo_root = vim.fn.fnamemodify(this_file, ":h:h:h") -- tests/nvim/minimal_init.lua → repo root

-- Production-equivalent leader (must come before plugin specs / any keymap).
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Add the repo's nvim/ tree (init.lua's stdpath-config equivalent).
vim.opt.runtimepath:prepend(repo_root .. "/nvim")

-- Plenary lives under XDG_DATA_HOME/lazy/plenary.nvim once lazy has cloned it.
-- For headless tests we keep plenary in a fixed cache dir under the repo so
-- the suite doesn't depend on a populated lazy data dir.
local function locked_plugin_commit(name)
  local lockfile = repo_root .. "/nvim/lazy-lock.json"
  local ok, lines = pcall(vim.fn.readfile, lockfile)
  if not ok or not lines or #lines == 0 then
    return nil
  end

  local decoded_ok, lock = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not decoded_ok or type(lock) ~= "table" or type(lock[name]) ~= "table" then
    return nil
  end
  return lock[name].commit
end

local function git_checked(args)
  vim.fn.system(args)
  if vim.v.shell_error ~= 0 then
    error("git failed: " .. table.concat(args, " "))
  end
end

local plenary_dir = repo_root .. "/tests/.cache/plenary.nvim"
if vim.fn.isdirectory(plenary_dir) == 0 then
  vim.fn.mkdir(vim.fn.fnamemodify(plenary_dir, ":h"), "p")
  git_checked({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/nvim-lua/plenary.nvim.git",
    plenary_dir,
  })
end
local plenary_commit = locked_plugin_commit("plenary.nvim")
if plenary_commit and vim.fn.isdirectory(plenary_dir .. "/.git") == 1 then
  local current = vim.fn.systemlist({ "git", "-C", plenary_dir, "rev-parse", "HEAD" })[1]
  if current ~= plenary_commit then
    git_checked({ "git", "-C", plenary_dir, "fetch", "--filter=blob:none", "origin", plenary_commit })
    git_checked({ "git", "-C", plenary_dir, "checkout", "--detach", plenary_commit })
  end
end
vim.opt.runtimepath:prepend(plenary_dir)
-- Explicitly source plenary's plugin file (plain `-u` doesn't auto-source
-- plugin/*.vim when --noplugin was passed by PlenaryBustedDirectory).
pcall(vim.cmd, "runtime plugin/plenary.vim")

-- Production options + the :WNF command.
require("vim-options")

-- Make the repo root reachable from tests for read-the-source assertions.
_G.TEST_REPO_ROOT = repo_root
