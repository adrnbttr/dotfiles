-- nvim-dap configuration for Node.js debugging in Docker
-- Supports auto-detection of debug ports and full debugging interface

return {
  -- Core DAP (Debug Adapter Protocol)
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
      "nvim-telescope/telescope-dap.nvim",
    },
    keys = {
      -- Debug keybindings with <leader>d prefix
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Debug: Toggle Breakpoint" },
      { "<leader>dc", function() require("config.dap").start_debug() end, desc = "Debug: Continue/Start" },
      { "<leader>ds", function() require("dap").step_over() end, desc = "Debug: Step Over" },
      { "<leader>di", function() require("dap").step_into() end, desc = "Debug: Step Into" },
      { "<leader>do", function() require("dap").step_out() end, desc = "Debug: Step Out" },
      { "<leader>dt", function() require("dapui").toggle() end, desc = "Debug: Toggle UI" },
      { "<leader>dx", function() require("dap").terminate() end, desc = "Debug: Stop" },
      { "<leader>dr", function() require("dap").repl.open() end, desc = "Debug: Open REPL" },
      { "<leader>dl", function() require("dap").run_last() end, desc = "Debug: Run Last" },
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")
      
      -- Setup DAP UI
      dapui.setup({
        icons = { expanded = "▾", collapsed = "▸", current_frame = "▸" },
        mappings = {
          expand = { "<CR>", "<2-LeftMouse>" },
          open = "o",
          remove = "d",
          edit = "e",
          repl = "r",
          toggle = "t",
        },
        layouts = {
          {
            elements = {
              { id = "scopes", size = 0.50 },
              { id = "stacks", size = 0.30 },
              { id = "watches", size = 0.20 },
            },
            size = 40,
            position = "left",
          },
          {
            elements = {
              { id = "repl", size = 0.60 },
              { id = "console", size = 0.40 },
            },
            size = 0.25,
            position = "bottom",
          },
        },
        controls = {
          enabled = true,
          element = "repl",
          icons = {
            pause = "",
            play = "",
            step_into = "",
            step_over = "",
            step_out = "",
            run_last = "",
            terminate = "",
          },
        },
        floating = {
          max_height = nil,
          max_width = nil,
          border = "single",
          mappings = {
            close = { "q", "<Esc>" },
          },
        },
        render = {
          max_type_length = nil,
          max_value_lines = 100,
        },
      })
      
      -- Automatically open/close DAP UI
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end
      
      -- Setup virtual text
      require("nvim-dap-virtual-text").setup({
        enabled = true,
        enabled_commands = true,
        highlight_changed_variables = true,
        highlight_new_as_changed = false,
        show_stop_reason = true,
        commented = false,
        only_first_definition = true,
        all_references = false,
        filter_references_pattern = '<module',
        virt_text_pos = 'eol',
        all_frames = false,
        virt_lines = false,
        virt_text_win_col = nil,
      })
      
      -- Setup telescope DAP
      require("telescope").load_extension("dap")
      
      -- Configure Node.js adapter for Docker debugging
      dap.adapters.node2 = {
        type = 'executable',
        command = 'node',
        args = { vim.fn.stdpath("data") .. '/mason/packages/vscode-js-debug/out/src/vsDebugServer.js' },
      }
      
      -- Configure Node.js debugging
      dap.configurations.javascript = {
        {
          type = 'node2',
          request = 'attach',
          name = 'Attach to Docker Node Process',
          port = 56745, -- Default port, will be overridden by port detection
          restart = true,
          sourceMaps = true,
          skipFiles = { '<node_internals>/**' },
          localRoot = vim.fn.getcwd(),
          remoteRoot = '/app', -- Adjust based on your Docker WORKDIR
        },
      }
      
      -- Support TypeScript as well
      dap.configurations.typescript = dap.configurations.javascript
    end,
  },
  
  -- Mason integration for automatic installation of debug adapters
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "js-debug-adapter" })
    end,
  },
}
