-- Leader must be set BEFORE lazy loads any plugin spec, otherwise
-- every plugin keymap that uses <leader> resolves to '\'.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local function config_dir()
  local src = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(vim.fn.resolve(src), ":p:h")
end

local function locked_plugin_commit(name)
  local lockfile = config_dir() .. "/lazy-lock.json"
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

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  git_checked({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
  local lazy_commit = locked_plugin_commit("lazy.nvim")
  if lazy_commit then
    git_checked({ "git", "-C", lazypath, "checkout", "--detach", lazy_commit })
  end
end
vim.opt.rtp:prepend(lazypath)

require("vim-options")
require("lazy").setup({
  spec = { { import = "plugins" } },
  change_detection = { notify = false },
  performance = {
    rtp = {
      -- Netrw stays enabled — it provides :Explore, gx URL-opening,
      -- and is what `:E` resolves to.
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
