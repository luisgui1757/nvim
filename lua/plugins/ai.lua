return {
  -- Base Copilot plugin (github/copilot.vim)
  {
    "github/copilot.vim",
    event = "InsertEnter",
    lazy = false, -- Force eager loading
    config = function()
      -- Disable the default <Tab> mapping
      vim.g.copilot_no_tab_map = true

      -- Map <C-l> to accept Copilot suggestion
      vim.api.nvim_set_keymap("i", "<C-l>", 'copilot#Accept("<CR>")', { silent = true, expr = true })
    end,
  },

  -- Copilot Chat for interactive chat interface
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "canary", -- Use the 'canary' branch
    cmd = "CopilotChat",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "nvim-lua/plenary.nvim",
      "github/copilot.vim",
    },
    opts = function()
      local user = vim.env.USER or "User"
      user = user:sub(1, 1):upper() .. user:sub(2)
      return {
        auto_insert_mode = true,
        show_help = true,
        allow_insecure = true,
        question_header = "  " .. user .. " ",
        answer_header = "  Copilot ",
        window = {
          width = 0.4,
        },
        selection = function(source)
          local select = require("CopilotChat.select")
          return select.visual(source) or select.buffer(source)
        end,
      }
    end,
    keys = {
      { "<c-s>",     "<CR>", ft = "copilot-chat", desc = "Submit Prompt", remap = true },
      { "<leader>a", "",     desc = "+AI",        mode = { "n", "v" } },
      {
        "<leader>aa",
        function()
          return require("CopilotChat").toggle()
        end,
        desc = "Toggle Copilot Chat",
        mode = { "n", "v" },
      },
      -- (Include other keybindings as needed)
    },
    config = function(_, opts)
      local chat = require("CopilotChat")

      -- No need to set up cmp integration with github/copilot.vim
      -- Remove or comment out the following line if present
      -- require("CopilotChat.integrations.cmp").setup()

      vim.api.nvim_create_autocmd("BufEnter", {
        pattern = "copilot-chat",
        callback = function()
          vim.opt_local.relativenumber = false
          vim.opt_local.number = false
        end,
      })

      chat.setup(opts)
    end,
  },
}
