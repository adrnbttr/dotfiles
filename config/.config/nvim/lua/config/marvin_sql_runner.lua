local M = {}

local dadbod = require("config.marvin_dadbod")

local state = {
  out_win = nil,
  out_buf = nil,
  out_height = 15,
}

local function is_valid_win(win)
  return win and vim.api.nvim_win_is_valid(win)
end

local function is_valid_buf(buf)
  return buf and vim.api.nvim_buf_is_valid(buf)
end

local function ensure_out_buf()
  if is_valid_buf(state.out_buf) then
    return state.out_buf
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "[Marvin DB Output]")
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  state.out_buf = buf
  return buf
end

local function open_output_win()
  if is_valid_win(state.out_win) then
    return state.out_win
  end

  local cur_win = vim.api.nvim_get_current_win()
  vim.cmd(string.format("botright %dsplit", state.out_height))
  state.out_win = vim.api.nvim_get_current_win()

  local buf = ensure_out_buf()
  vim.api.nvim_win_set_buf(state.out_win, buf)

  vim.wo[state.out_win].wrap = false
  vim.wo[state.out_win].number = false
  vim.wo[state.out_win].relativenumber = false
  vim.wo[state.out_win].signcolumn = "no"
  vim.wo[state.out_win].winfixheight = true

  vim.api.nvim_set_current_win(cur_win)
  return state.out_win
end

local function close_output_win()
  if is_valid_win(state.out_win) then
    vim.api.nvim_win_close(state.out_win, true)
  end
  state.out_win = nil
end

function M.toggle_output()
  if is_valid_win(state.out_win) then
    close_output_win()
  else
    open_output_win()
  end
end

local function find_dadbod_preview_win()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.wo[win].previewwindow then
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].filetype == "dbout" then
        return win, buf
      end
    end
  end
  return nil, nil
end

local function capture_preview_to_output(return_win)
  local pwin, pbuf = find_dadbod_preview_win()
  if not pwin or not pbuf then
    return
  end

  open_output_win()
  state.out_buf = pbuf
  if is_valid_win(state.out_win) then
    vim.api.nvim_win_set_buf(state.out_win, pbuf)
  end

  if vim.bo[pbuf].filetype == "dbout" then
    M.setup_dbout(pbuf)
  end

  if is_valid_win(pwin) then
    vim.api.nvim_win_close(pwin, true)
  end

  if is_valid_win(return_win) then
    vim.api.nvim_set_current_win(return_win)
  end
end

local function dbout_path_from_user_match(match)
  if type(match) ~= "string" or match == "" then
    return nil
  end
  -- dadbod triggers doautocmd User {output}/DBExecutePost
  local p = match:gsub("/DBExecutePost$", "")
  p = p:gsub("DBExecutePost$", "")
  p = p:gsub("/+$", "")
  if p:match("%.dbout$") then
    return p
  end
  return nil
end

function M.capture_dbout(match)
  local return_win = vim.api.nvim_get_current_win()

  local path = dbout_path_from_user_match(match)
  if path then
    local bufnr = vim.fn.bufnr(path)
    if bufnr == -1 then
      bufnr = vim.fn.bufadd(path)
    end
    pcall(vim.fn.bufload, bufnr)

    open_output_win()
    state.out_buf = bufnr
    if is_valid_win(state.out_win) then
      vim.api.nvim_win_set_buf(state.out_win, bufnr)
    end

    if vim.bo[bufnr].filetype == "dbout" then
      M.setup_dbout(bufnr)
    end

    -- Close any preview window displaying this dbout.
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.wo[win].previewwindow then
        local b = vim.api.nvim_win_get_buf(win)
        if b == bufnr and is_valid_win(win) then
          pcall(vim.api.nvim_win_close, win, true)
        end
      end
    end

    if is_valid_win(return_win) then
      vim.api.nvim_set_current_win(return_win)
    end
    return true
  end

  capture_preview_to_output(return_win)
  return true
end

function M.setup_dbout(bufnr)
  if not bufnr or bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  if vim.bo[bufnr].filetype ~= "dbout" then
    return
  end

  -- Ensure horizontal scrolling works (requires nowrap in the window).
  pcall(function()
    vim.wo.wrap = false
  end)

  if vim.b[bufnr].marvin_shift_wheel_horizontal then
    return
  end
  vim.b[bufnr].marvin_shift_wheel_horizontal = true

  -- Map multiple variants since some terminals don't encode modifiers.
  local function left()
    vim.cmd("normal! zH")
  end
  local function right()
    vim.cmd("normal! zL")
  end

  vim.keymap.set("n", "<S-ScrollWheelUp>", left, {
    buffer = bufnr,
    silent = true,
    desc = "DB: Scroll left (Shift+wheel)",
  })
  vim.keymap.set("n", "<S-ScrollWheelDown>", right, {
    buffer = bufnr,
    silent = true,
    desc = "DB: Scroll right (Shift+wheel)",
  })
  vim.keymap.set("n", "<ScrollWheelLeft>", left, {
    buffer = bufnr,
    silent = true,
    desc = "DB: Scroll left (wheel)",
  })
  vim.keymap.set("n", "<ScrollWheelRight>", right, {
    buffer = bufnr,
    silent = true,
    desc = "DB: Scroll right (wheel)",
  })
end

local function buf_line_count(bufnr)
  return vim.api.nvim_buf_line_count(bufnr)
end

local function get_statement_range(bufnr)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cur = cursor[1]
  local lines = buf_line_count(bufnr)

  local start_line = 1
  for l = cur - 1, 1, -1 do
    local text = vim.api.nvim_buf_get_lines(bufnr, l - 1, l, false)[1] or ""
    if text:find(";", 1, true) then
      start_line = l + 1
      break
    end
  end

  local end_line = lines
  for l = cur, lines do
    local text = vim.api.nvim_buf_get_lines(bufnr, l - 1, l, false)[1] or ""
    if text:find(";", 1, true) then
      end_line = l
      break
    end
  end

  if start_line > end_line then
    start_line = 1
    end_line = lines
  end

  return start_line, end_line
end

local function ensure_connection(bufnr)
  dadbod.maybe_apply(bufnr, { silent = true })
  local dsn = vim.b[bufnr].db
  if not dsn or dsn == "" then
    vim.notify("marvin-dadbod: no connection for this SQL file", vim.log.levels.WARN)
    return false
  end
  return true
end

function M.execute_statement()
  local bufnr = vim.api.nvim_get_current_buf()
  if not ensure_connection(bufnr) then
    return
  end

  local s, e = get_statement_range(bufnr)
  local return_win = vim.api.nvim_get_current_win()

  vim.cmd(string.format("%d,%dDB", s, e))
  vim.defer_fn(function()
    capture_preview_to_output(return_win)
  end, 60)
end

function M.execute_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  if not ensure_connection(bufnr) then
    return
  end

  local return_win = vim.api.nvim_get_current_win()
  vim.cmd("%DB")
  vim.defer_fn(function()
    capture_preview_to_output(return_win)
  end, 60)
end

return M
