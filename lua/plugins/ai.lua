return {
  -- Base Copilot plugin
  {
    "zbirenbaum/copilot.lua",
    event = "InsertEnter",
    config = function()
      require("copilot").setup({
        suggestion = {
          enabled = true,
          auto_trigger = true,
          keymap = {
            accept = "<C-l>",
            next = "<C-]>",
            prev = "<C-p>", -- Avoid conflict with Esc
            dismiss = "<C-\\>",
          },
        },
        panel = { enabled = true },
      })
    end,
  },

  -- Copilot CMP integration
  {
    "zbirenbaum/copilot-cmp",
    after = { "copilot.lua", "nvim-cmp" },
    config = function()
      require("copilot_cmp").setup()
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
      "zbirenbaum/copilot.lua",
    },
    opts = function()
      local user = vim.env.USER or "User"
      user = user:sub(1, 1):upper() .. user:sub(2)
      return {
        auto_insert_mode = true,
        show_help = true,
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
      {
        "<leader>ax",
        function()
          return require("CopilotChat").reset()
        end,
        desc = "Clear Copilot Chat",
        mode = { "n", "v" },
      },
      {
        "<leader>aq",
        function()
          local input = vim.fn.input("Quick Chat: ")
          if input ~= "" then
            require("CopilotChat").ask(input)
          end
        end,
        desc = "Quick Chat",
        mode = { "n", "v" },
      },
      -- New keybindings for CopilotChat commands
      {
        "<leader>ao",
        "<cmd>CopilotChatOptimize<CR>",
        desc = "Optimize Code with Copilot",
        mode = { "n", "v" },
      },
      {
        "<leader>ad",
        "<cmd>CopilotChatDocs<CR>",
        desc = "Generate Documentation with Copilot",
        mode = { "n", "v" },
      },
      {
        "<leader>ae",
        "<cmd>CopilotChatExplain<CR>",
        desc = "Explain Code with Copilot",
        mode = { "n", "v" },
      },
      {
        "<leader>af",
        "<cmd>CopilotChatFix<CR>",
        desc = "Fix Code with Copilot",
        mode = { "n", "v" },
      },
      {
        "<leader>ar",
        "<cmd>CopilotChatReview<CR>",
        desc = "Review Code with Copilot",
        mode = { "n", "v" },
      },
      {
        "<leader>at",
        "<cmd>CopilotChatTests<CR>",
        desc = "Generate Tests with Copilot",
        mode = { "n", "v" },
      },
    },
    config = function(_, opts)
      local chat = require("CopilotChat")
      require("CopilotChat.integrations.cmp").setup()

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
