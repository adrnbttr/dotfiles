-- Vim-dadbod: Database client for PostgreSQL, MongoDB, MySQL, etc.
return {
  {
    "tpope/vim-dadbod",
    dependencies = {
      "kristijanhusak/vim-dadbod-ui",
      "kristijanhusak/vim-dadbod-completion",
    },
    keys = {
      { "<leader>du", "<cmd>DBUIToggle<cr>", desc = "Toggle DB UI" },
      { "<leader>df", "<cmd>DBUIFindBuffer<cr>", desc = "Find DB buffer" },
      { "<leader>dr", "<cmd>DBUIRenameBuffer<cr>", desc = "Rename DB buffer" },
      { "<leader>dl", "<cmd>DBUILastQueryInfo<cr>", desc = "Last DB query info" },
    },
    config = function()
      -- Database connections configuration
      vim.g.db_ui_save_location = vim.fn.stdpath("data") .. "/dadbod_ui"
      vim.g.db_ui_show_database_icon = 1
      vim.g.db_ui_force_echo_notifications = 1
      vim.g.db_ui_use_nerd_fonts = 1
      vim.g.db_ui_win_position = "left"
      vim.g.db_ui_winwidth = 30
      
      -- Configure auto-completion for SQL files
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "sql", "mysql", "plsql" },
        callback = function()
          require("cmp").setup.buffer({
            sources = {
              { name = "vim-dadbod-completion" },
              { name = "buffer" },
            },
          })
        end,
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
