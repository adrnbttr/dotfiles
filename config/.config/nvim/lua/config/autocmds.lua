-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Open the file explorer (LazyVim default: neo-tree) on startup.
-- This file itself is loaded on the VeryLazy event, so we just schedule
-- the open from here.
local function marvin_open_explorer_once()
  if vim.g.__marvin_explorer_opened then
    return
  end
  vim.g.__marvin_explorer_opened = true

  if vim.g.marvin_explorer_autostart == false or vim.env.NVIM_NO_EXPLORER == "1" then
    return
  end

  -- Skip in headless mode
  if #vim.api.nvim_list_uis() == 0 then
    return
  end

  -- Skip for special modes (help, git commit, etc.)
  local ft = vim.bo.filetype
  if ft == "gitcommit" or ft == "gitrebase" or ft == "help" then
    return
  end

  vim.schedule(function()
    if vim.fn.exists(":Neotree") ~= 2 then
      vim.notify("neo-tree not available (command :Neotree missing)", vim.log.levels.WARN)
      return
    end

    local cur_win = vim.api.nvim_get_current_win()
    -- Don't use :silent! so failures are visible.
    pcall(vim.cmd, "Neotree show")
    if vim.api.nvim_win_is_valid(cur_win) then
      pcall(vim.api.nvim_set_current_win, cur_win)
    end
  end)
end

marvin_open_explorer_once()
