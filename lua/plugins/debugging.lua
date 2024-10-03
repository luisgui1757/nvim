return {
  -- Setup for nvim-dap
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      -- Setup dap-ui
      dapui.setup()

      -- Configure GDB as the DAP adapter for C++
      dap.adapters.gdb = {
        type = "executable",
        command = "gdb",
        args = { "-i", "dap" },
      }

      -- DAP configuration for C++
      dap.configurations.cpp = {
        {
          name = "Launch",
          type = "gdb",
          request = "launch",
          program = function()
            return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
          end,
          cwd = "${workspaceFolder}",
          stopAtBeginningOfMainSubprogram = false,
        },
      }

      -- Setup event listeners for dap-ui
      dap.listeners.before.attach.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.launch.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated.dapui_config = function()
        dapui.close()
      end
      dap.listeners.before.event_exited.dapui_config = function()
        dapui.close()
      end

      -- Keybindings for DAP
      vim.keymap.set("n", "<Leader>dt", dap.toggle_breakpoint, {})
      vim.keymap.set("n", "<F5>", function()
        require("dap").continue()
      end)
      vim.keymap.set("n", "<F10>", function()
        require("dap").step_over()
      end)
      vim.keymap.set("n", "<F11>", function()
        require("dap").step_into()
      end)
      vim.keymap.set("n", "<F12>", function()
        require("dap").step_out()
      end)
    end,
  },

  -- Setup for Python DAP using mason and dap-python
  {
    "mfussenegger/nvim-dap-python",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "williamboman/mason.nvim",  -- Add mason.nvim as a dependency
    },
    config = function()
      local dap_python = require("dap-python")
      local mason_registry = require("mason-registry")

      -- Ensure Mason is set up
      require("mason").setup()

      -- Ensure the package 'debugpy' is installed
      if mason_registry.is_installed("debugpy") then
        local package = mason_registry.get_package("debugpy")
        local package_path = package:get_install_path()

        -- Setup dap-python with the correct executable path
        dap_python.setup(package_path .. "/venv/bin/python")
      else
        print("debugpy is not installed. Please install via :Mason")
      end
    end,
  },

  -- Setup for Mason itself
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup()
    end,
  },
}
