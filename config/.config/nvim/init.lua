-- bootstrap lazy.nvim, lazyvim and your plugins
require("config.lazy")

-- Setup poetry runner for Python development
-- Setup Claude Code integration
require("config.claude").setup()
require("config.poetry_runner").setup()

vim.cmd("colorscheme citruszest")