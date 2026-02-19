-- Toggleterm configuration for terminal management in nvim
-- Provides floating, horizontal, and vertical terminals

return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    keys = {
      -- Toggle terminal (default: float)
      { "<leader>tt", "<cmd>ToggleTerm direction=float<cr>", desc = "Toggle Terminal (float)" },
      { "<C-t>", "<cmd>ToggleTerm direction=float<cr>", desc = "Toggle Terminal (float)", mode = { "n", "t" } },
      
      -- Different orientations
      { "<leader>tf", "<cmd>ToggleTerm direction=float<cr>", desc = "Floating Terminal" },
      { "<leader>th", "<cmd>ToggleTerm direction=horizontal<cr>", desc = "Horizontal Terminal" },
      { "<leader>tv", "<cmd>ToggleTerm direction=vertical<cr>", desc = "Vertical Terminal" },
      
      -- Multiple terminals
      { "<leader>t1", "<cmd>1ToggleTerm<cr>", desc = "Terminal 1" },
      { "<leader>t2", "<cmd>2ToggleTerm<cr>", desc = "Terminal 2" },
      { "<leader>t3", "<cmd>3ToggleTerm<cr>", desc = "Terminal 3" },
      { "<leader>ts", "<cmd>TermSelect<cr>", desc = "Select Terminal" },
      
      -- Tools
      { "<leader>tg", "<cmd>lua _LAZYGIT_TOGGLE()<cr>", desc = "Lazygit" },
    },
    opts = {
      size = function(term)
        if term.direction == "horizontal" then
          return 15
        elseif term.direction == "vertical" then
          return vim.o.columns * 0.3
        end
      end,
      float_opts = {
        border = "curved",
        winblend = 3,
        width = math.floor(vim.o.columns * 0.8),
        height = math.floor(vim.o.lines * 0.8),
      },
      persist_size = true,
      persist_mode = true,
      start_in_insert = true,
      shade_terminals = true,
      shading_factor = 2,
    },
    config = function(_, opts)
      require("toggleterm").setup(opts)
      
      -- Enable <C-t> to toggle terminal from terminal insert mode
      vim.keymap.set('t', '<C-t>', '<C-\\><C-n><cmd>ToggleTerm direction=float<cr>', { noremap = true, desc = "Toggle terminal" })
      
      -- Enable <Esc> to exit terminal insert mode
      vim.keymap.set('t', '<Esc>', '<C-\\><C-n>', { noremap = true, desc = "Exit terminal insert mode" })
      
      -- Automatically enter insert mode when opening a terminal
      vim.api.nvim_create_autocmd("BufEnter", {
        pattern = "term://*",
        callback = function()
          vim.defer_fn(function()
            vim.cmd("startinsert")
          end, 10)
        end,
      })
      
      -- Lazygit floating terminal
      local Terminal = require("toggleterm.terminal").Terminal
      local lazygit = Terminal:new({
        cmd = "lazygit",
        hidden = true,
        direction = "float",
        float_opts = {
          border = "curved",
        },
      })
      
      _G._LAZYGIT_TOGGLE = function()
        lazygit:toggle()
      end
    end,
  },
}
