return {
	{
		"williamboman/mason.nvim",
		cmd = "Mason",
		build = ":MasonUpdate",
		config = function()
			require("mason").setup({
				ui = {
					border = "rounded",
					icons = {
						package_installed = "✓",
						package_pending = "➜",
						package_uninstalled = "✗",
					},
				},
			})
		end,
	},
	{
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		event = "VeryLazy",
		dependencies = { "williamboman/mason.nvim" },
		config = function()
			require("mason-tool-installer").setup({
				ensure_installed = {
					-- LSP servers (installed via Mason, enabled via vim.lsp.enable below)
					"lua-language-server",
					"clangd",
					"pyright",
					"rust-analyzer",
					"bash-language-server",
					"yaml-language-server",
					"json-lsp",
					"neocmakelsp",
					"powershell-editor-services",
					-- Formatters (used by conform.nvim)
					"stylua",
					"shfmt",
					"prettier",
					"clang-format",
					"gersemi",
					"ruff",
					-- DAP adapters
					"js-debug-adapter",
				},
				auto_update = false,
				run_on_start = true,
			})
		end,
	},
	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = { "hrsh7th/cmp-nvim-lsp" },
		config = function()
			local capabilities = require("cmp_nvim_lsp").default_capabilities()

			-- Keep LSP log size sane
			vim.lsp.set_log_level("ERROR")

			-- NOTE: format-on-save lives in conform.nvim, NOT here.
			-- Don't add a BufWritePre formatter here or it will race conform.

			-- clangd: look for compile_commands.json in fixed root-relative locations.
			-- Avoid the recursive `o/**` glob — it traversed huge build trees on
			-- every first buffer open. clangd already auto-discovers ancestors
			-- of the file's directory, so this just nudges the *workspace* root.
			local function get_clangd_cmd()
				local cmd = { "clangd", "--background-index", "--clang-tidy" }
				local fixed_candidates = {
					"compile_commands.json",
					"build/compile_commands.json",
					"out/compile_commands.json",
					".cache/clangd/compile_commands.json",
				}
				for _, rel in ipairs(fixed_candidates) do
					if vim.uv.fs_stat(rel) then
						table.insert(cmd, "--compile-commands-dir=" .. vim.fn.fnamemodify(rel, ":h"))
						break
					end
				end
				return cmd
			end

			vim.lsp.config("clangd", {
				cmd = get_clangd_cmd(),
				capabilities = capabilities,
				root_markers = { "compile_commands.json", ".clangd", "CMakeLists.txt", ".git" },
			})

			vim.lsp.config("lua_ls", {
				capabilities = capabilities,
				root_markers = { ".luarc.json", ".luarc.jsonc", ".git" },
				settings = {
					Lua = {
						workspace = { checkThirdParty = false },
						telemetry = { enable = false },
					},
				},
			})

			vim.lsp.config("pyright", {
				capabilities = capabilities,
				root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" },
			})

			vim.lsp.config("rust_analyzer", {
				capabilities = capabilities,
				root_markers = { "Cargo.toml", "rust-project.json", ".git" },
				settings = {
					["rust-analyzer"] = {
						cargo = { allFeatures = true },
						checkOnSave = { command = "clippy" },
					},
				},
			})

			vim.lsp.config("bashls", {
				capabilities = capabilities,
				filetypes = { "sh", "bash", "zsh" },
				root_markers = { ".git" },
			})

			vim.lsp.config("yamlls", {
				capabilities = capabilities,
				root_markers = { ".git" },
				settings = {
					yaml = {
						keyOrdering = false,
						format = { enable = true },
					},
				},
			})

			vim.lsp.config("jsonls", {
				capabilities = capabilities,
				root_markers = { ".git" },
			})

			vim.lsp.config("neocmake", {
				capabilities = capabilities,
				root_markers = { "CMakeLists.txt", ".git" },
			})

			vim.lsp.config("powershell_es", {
				capabilities = capabilities,
				root_markers = { ".git" },
				bundle_path = vim.fn.stdpath("data") .. "/mason/packages/powershell-editor-services",
			})

			vim.lsp.enable({
				"clangd",
				"lua_ls",
				"pyright",
				"rust_analyzer",
				"bashls",
				"yamlls",
				"jsonls",
				"neocmake",
				"powershell_es",
			})

			-- Race fix: if a buffer opened *before* mason-tool-installer
			-- finished installing its server, those buffers won't have an
			-- LSP client. Re-fire the LspAttach codepath for each loaded
			-- buffer by issuing :edit INSIDE THAT BUFFER via nvim_buf_call
			-- (the previous version only re-edited the current buffer for
			-- every iteration, leaving background buffers stranded).
			vim.api.nvim_create_autocmd("User", {
				pattern = "MasonToolsUpdateCompleted",
				callback = function()
					for _, buf in ipairs(vim.api.nvim_list_bufs()) do
						if vim.api.nvim_buf_is_loaded(buf)
							and vim.bo[buf].buftype == ""
							and vim.api.nvim_buf_get_name(buf) ~= ""
						then
							pcall(vim.api.nvim_buf_call, buf, function()
								vim.cmd("edit")
							end)
						end
					end
				end,
			})

			-- Diagnostic UI
			vim.diagnostic.config({
				virtual_text = { spacing = 2, prefix = "●" },
				signs = true,
				underline = true,
				update_in_insert = false,
				severity_sort = true,
				float = { border = "rounded", source = "if_many" },
			})

			-- Keymaps
			local opts = { noremap = true, silent = true }
			vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
			vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
			vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
			vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
			vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
			vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)
			vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
			vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)
			-- Nvim 0.11+: vim.diagnostic.goto_prev/goto_next are deprecated in
			-- favor of vim.diagnostic.jump.
			vim.keymap.set("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, opts)
			vim.keymap.set("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, opts)
			vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, opts)
		end,
	},
}
