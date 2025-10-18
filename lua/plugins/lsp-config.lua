return {
	{
		"williamboman/mason.nvim",
		cmd = "Mason",
		build = ":MasonUpdate",
		config = function()
			require("mason").setup()
		end,
	},
	{
		"williamboman/mason-lspconfig.nvim",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = { "williamboman/mason.nvim" },
		config = function()
			require("mason-lspconfig").setup({
				ensure_installed = { "lua_ls", "clangd", "pyright" },
				automatic_installation = true,
			})
		end,
	},
	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = { "hrsh7th/cmp-nvim-lsp" },
		config = function()
			local capabilities = require("cmp_nvim_lsp").default_capabilities()

			-- Disable verbose LSP logging (keeps log files small)
			vim.lsp.set_log_level("ERROR") -- Only log errors, not every request

			-- Auto-format on save
			vim.api.nvim_create_autocmd("LspAttach", {
				callback = function(args)
					local client = vim.lsp.get_client_by_id(args.data.client_id)
					if client and client.supports_method("textDocument/formatting") then
						vim.api.nvim_create_autocmd("BufWritePre", {
							buffer = args.buf,
							callback = function()
								vim.lsp.buf.format({ async = false, timeout_ms = 3000 })
							end,
						})
					end
				end,
			})

			-- Find compile_commands.json for clangd
			local function get_clangd_cmd()
				local cmd = { "clangd" }
				local compile_commands = vim.fn.glob("./o/**/compile_commands.json", true, true)
				if #compile_commands > 0 then
					table.insert(cmd, "--compile-commands-dir=" .. vim.fn.fnamemodify(compile_commands[1], ":h"))
				end
				return cmd
			end

			-- Configure LSP servers using new vim.lsp.config API
			vim.lsp.config("clangd", {
				cmd = get_clangd_cmd(),
				capabilities = capabilities,
				root_markers = { "compile_commands.json", ".git" },
			})

			vim.lsp.config("lua_ls", {
				capabilities = capabilities,
				root_markers = { ".luarc.json", ".git" },
			})

			vim.lsp.config("pyright", {
				capabilities = capabilities,
				root_markers = { "pyproject.toml", "setup.py", ".git" },
			})

			-- Enable servers
			vim.lsp.enable({ "clangd", "lua_ls", "pyright" })

			-- Keymaps
			local opts = { noremap = true, silent = true }
			vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
			vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
			vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
			vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
			vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)
			vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)
			vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
			vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
			vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, opts)
		end,
	},
}
