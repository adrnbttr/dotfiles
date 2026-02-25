-- Vim-dadbod: Database client for PostgreSQL, MongoDB, MySQL, etc.
return {
  {
    "tpope/vim-dadbod",
    ft = { "sql", "mysql", "plsql" },
    dependencies = {
      "kristijanhusak/vim-dadbod-ui",
      "kristijanhusak/vim-dadbod-completion",
    },
    keys = {
      -- Use <leader>m* to avoid clashing with <leader>d (DAP)
      { "<leader>mu", "<cmd>DBUIToggle<cr>", desc = "DB: Toggle UI" },
      { "<leader>mf", "<cmd>DBUIFindBuffer<cr>", desc = "DB: Find buffer" },
      { "<leader>mr", "<cmd>DBUIRenameBuffer<cr>", desc = "DB: Rename buffer" },
      { "<leader>ml", "<cmd>DBUILastQueryInfo<cr>", desc = "DB: Last query info" },

      -- Marvin SQL runner (declare keys here so lazy.nvim creates them
      -- even before dadbod is loaded).
      {
        "<leader>ms",
        function()
          local md = require("config.marvin_dadbod")
          local path = vim.api.nvim_buf_get_name(0)
          if not md.is_target_path(path) then
            vim.notify("marvin-dadbod: SQL runner only applies to project SQL paths", vim.log.levels.WARN)
            return
          end
          require("config.marvin_sql_runner").execute_statement()
        end,
        desc = "DB: Execute statement",
      },
      {
        "<leader>mS",
        function()
          local md = require("config.marvin_dadbod")
          local path = vim.api.nvim_buf_get_name(0)
          if not md.is_target_path(path) then
            vim.notify("marvin-dadbod: SQL runner only applies to project SQL paths", vim.log.levels.WARN)
            return
          end
          require("config.marvin_sql_runner").execute_buffer()
        end,
        desc = "DB: Execute buffer",
      },
      {
        "<leader>mo",
        function()
          require("config.marvin_sql_runner").toggle_output()
        end,
        desc = "DB: Toggle output",
      },
    },
    config = function()
      -- Database connections configuration
      vim.g.db_ui_save_location = vim.fn.stdpath("data") .. "/dadbod_ui"
      vim.g.db_ui_show_database_icon = 1
      vim.g.db_ui_force_echo_notifications = 1
      vim.g.db_ui_use_nerd_fonts = 1
      vim.g.db_ui_win_position = "left"
      vim.g.db_ui_winwidth = 30
      vim.g.db_ui_auto_execute_table_helpers = 1

      -- Marvin: default mode (user requested prod by default)
      vim.g.marvin_db_mode = vim.g.marvin_db_mode or "prod"
      
      -- Configure auto-completion for SQL files
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "sql", "mysql", "plsql" },
        callback = function()
          local ok, cmp = pcall(require, "cmp")
          if ok then
            cmp.setup.buffer({
              sources = {
                { name = "vim-dadbod-completion" },
                { name = "buffer" },
              },
            })
          end
        end,
      })

      -- Auto-configure dadbod connection for project SQL files
      local group = vim.api.nvim_create_augroup("MarvinDadbod", { clear = true })

      vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "BufEnter" }, {
        group = group,
        pattern = "*.sql",
        callback = function(args)
          require("config.marvin_dadbod").maybe_apply(args.buf, { silent = true })
        end,
      })

      -- Ensure dbout buffers always have Marvin navigation helpers.
      vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
        group = group,
        pattern = { "dbout", "*.dbout" },
        callback = function(args)
          if vim.bo[args.buf].filetype ~= "dbout" then
            return
          end
          pcall(function()
            vim.wo.wrap = false
          end)
          pcall(require("config.marvin_sql_runner").setup_dbout, args.buf)
        end,
      })

      -- Mirror dadbod output into the Marvin bottom split.
      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "*/DBExecutePost",
        callback = function(args)
          pcall(require("config.marvin_sql_runner").capture_dbout, args.match)
        end,
      })

      -- SQL runner keymaps (only for matching project paths)
      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "sql",
        callback = function(args)
          local md = require("config.marvin_dadbod")
          local path = vim.api.nvim_buf_get_name(args.buf)
          if not md.is_target_path(path) then
            return
          end

          local runner = require("config.marvin_sql_runner")
          vim.keymap.set("n", "<leader>ms", runner.execute_statement, {
            buffer = args.buf,
            desc = "DB: Execute statement",
          })
          vim.keymap.set("n", "<leader>mS", runner.execute_buffer, {
            buffer = args.buf,
            desc = "DB: Execute buffer",
          })
          vim.keymap.set("n", "<leader>mo", runner.toggle_output, {
            buffer = args.buf,
            desc = "DB: Toggle output",
          })
        end,
      })

      -- :MarvinDbMode local|prod
      vim.api.nvim_create_user_command("MarvinDbMode", function(cmd)
        require("config.marvin_dadbod").set_mode(cmd.args)
      end, {
        nargs = 1,
        complete = function()
          return { "local", "prod" }
        end,
        desc = "Set Marvin dadbod mode (local/prod)",
      })
      
      -- Example connections (you can add your own in ~/.config/nvim/lua/config/dadbod-connections.lua)
      -- These are templates - customize with your actual credentials
      vim.g.dbs = vim.g.dbs or {}
      
      -- Add your database connections here or in a separate file
      -- Format: Name = "protocol://user:password@host:port/database"
      -- Example:
      -- vim.g.dbs = {
      --   postgres_local = "postgres://user:pass@localhost:5432/mydb",
      --   mongodb_local = "mongodb://user:pass@localhost:27017/mydb",
      -- }
    end,
  },
}
