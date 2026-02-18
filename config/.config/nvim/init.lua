-- bootstrap lazy.nvim, lazyvim and your plugins
require("config.lazy")

-- Setup poetry runner for Python development
require("config.poetry_runner").setup()

vim.cmd("colorscheme citruszest")