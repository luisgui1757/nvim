-- Cross-platform notes/vault path resolver.
-- uname_fn and env_fn are dependency-injected so tests can stub them.
local M = {}

function M.resolve(uname_fn, env_fn)
	uname_fn = uname_fn or vim.uv.os_uname
	env_fn = env_fn or vim.fn.getenv
	local home = vim.fn.expand("~")
	local uname = uname_fn() or {}
	local sysname = uname.sysname or ""
	local release = (uname.release or ""):lower()
	local is_wsl = release:find("microsoft") ~= nil or release:find("wsl") ~= nil

	if sysname == "Darwin" then
		return home .. "/Library/Mobile Documents/iCloud~md~obsidian/Documents/user"
	end

	if is_wsl then
		-- Prefer an explicit override; otherwise ask cmd.exe for the Windows
		-- username (WSL and Windows usernames can differ, so falling back to
		-- the WSL home basename can produce a wrong path).
		local winuser = env_fn("WINUSER")
		if winuser == nil or winuser == vim.NIL or winuser == "" then
			local ok, raw = pcall(vim.fn.system, { "cmd.exe", "/c", "echo %USERNAME%" })
			if ok and type(raw) == "string" then
				winuser = raw:gsub("[\r\n%s]+$", "")
			end
		end
		if winuser == nil or winuser == vim.NIL or winuser == "" then
			winuser = vim.fn.fnamemodify(home, ":t")
		end
		return "/mnt/c/Users/" .. winuser .. "/OneDrive - Employer/Notes/professional-vault"
	end

	if sysname:match("Windows") or sysname:match("MINGW") then
		local userprofile = env_fn("USERPROFILE")
		if userprofile == nil or userprofile == vim.NIL or userprofile == "" then
			userprofile = home
		end
		return userprofile .. "/OneDrive - Employer/Notes/professional-vault"
	end

	-- Native Linux (no WSL): personal vault fallback under ~/notes
	return home .. "/notes"
end

return M
