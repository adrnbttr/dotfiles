-- Poetry runner: Execute Python scripts via poetry from nvim
-- Uses toggleterm with poetry shell activation

local M = {}

-- Terminal instance for poetry commands
local poetry_terminal = nil
-- Track if this is the first time we're opening the terminal
local poetry_terminal_initialized = false

-- Find the project root (where pyproject.toml is)
local function find_project_root()
  local current_file = vim.fn.expand("%:p")
  local current_dir = vim.fn.fnamemodify(current_file, ":h")
  
  -- Walk up directory tree looking for pyproject.toml
  local dir = current_dir
  for _ = 1, 20 do -- safety limit
    local pyproject = dir .. "/pyproject.toml"
    if vim.fn.filereadable(pyproject) == 1 then
      return dir
    end
    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then
      break -- reached root
    end
    dir = parent
  end
  
  return nil
end

-- Execute the current Python file via poetry in toggleterm
function M.run()
  local project_root = find_project_root()
  if not project_root then
    vim.notify("No pyproject.toml found in project tree", vim.log.levels.ERROR)
    return
  end
  
  local current_file = vim.fn.expand("%:p")
  local relative_path = vim.fn.fnamemodify(current_file, ":~:.")
  
  -- Build the command to execute
  local cmd = string.format("poetry run python3 %s", relative_path)
  
  -- Create or get the poetry terminal
  local Terminal = require("toggleterm.terminal").Terminal
  
  if not poetry_terminal then
    -- Create new terminal with poetry shell
    poetry_terminal = Terminal:new({
      cmd = "poetry shell",
      direction = "float",
      close_on_exit = false,
      float_opts = {
        border = "curved",
        width = math.floor(vim.o.columns * 0.9),
        height = math.floor(vim.o.lines * 0.9),
      },
      on_open = function(term)
        vim.cmd("startinsert!")
        -- Only send command on first initialization
        if not poetry_terminal_initialized then
          -- Send the command after a short delay to let poetry shell initialize
          vim.defer_fn(function()
            if term and term:is_open() then
              term:send(cmd)
              poetry_terminal_initialized = true
            end
          end, 1500) -- 1.5 second delay for poetry shell to activate
        end
      end,
    })
    -- Open the terminal
    poetry_terminal:open()
  else
    -- Terminal already exists, just show it and send command
    if not poetry_terminal:is_open() then
      poetry_terminal:open()
    end
    poetry_terminal:send(cmd)
  end
  
  vim.notify("Poetry shell activated, running: " .. cmd, vim.log.levels.INFO)
end

-- Setup function to create command and keymaps
function M.setup()
  -- Create :PoetryRun command
  vim.api.nvim_create_user_command("PoetryRun", function()
    M.run()
  end, { desc = "Run current Python file via poetry in toggleterm" })
  
  -- Map <leader>pr in Python files
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "python",
    callback = function()
      vim.keymap.set("n", "<leader>pr", function()
        M.run()
      end, { buffer = true, desc = "Poetry run current file" })
    end,
  })
end

return M
