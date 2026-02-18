-- Poetry runner: Execute Python scripts via poetry from nvim
-- Sends commands to adjacent kitty terminal window

local M = {}

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

-- Execute the current Python file via poetry in kitty terminal
function M.run()
  local project_root = find_project_root()
  if not project_root then
    vim.notify("No pyproject.toml found in project tree", vim.log.levels.ERROR)
    return
  end
  
  local current_file = vim.fn.expand("%:p")
  local relative_path = vim.fn.fnamemodify(current_file, ":~:.")
  
  -- Build the command
  local cmd = string.format("cd %s && poetry run python3 %s", project_root, relative_path)
  
  -- Send to kitty terminal using kitten @
  -- This assumes the terminal is in the same kitty instance
  local kitty_cmd = string.format("kitten @ send-text --match=num:1 '%s\n'", cmd:gsub("'", "'\"'\"'"))
  
  local handle = io.popen(kitty_cmd .. " 2>&1")
  if handle then
    local result = handle:read("*a")
    handle:close()
    
    if result == "" then
      vim.notify("Sent to kitty: " .. cmd, vim.log.levels.INFO)
    else
      vim.notify("Error sending to kitty: " .. result, vim.log.levels.ERROR)
    end
  else
    vim.notify("Failed to execute kitty command", vim.log.levels.ERROR)
  end
end

-- Setup function to create command and keymaps
function M.setup()
  -- Create :PoetryRun command
  vim.api.nvim_create_user_command("PoetryRun", function()
    M.run()
  end, { desc = "Run current Python file via poetry in kitty terminal" })
  
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
