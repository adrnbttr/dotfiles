-- bootstrap lazy.nvim, lazyvim and your plugins
require("config.lazy")

-- Setup Claude Code integration
require("config.claude").setup()

-- Setup poetry runner for Python development
require("config.poetry_runner").setup()

vim.cmd("colorscheme citruszest")