local M = {}

local uv = vim.uv or vim.loop
local ns = vim.api.nvim_create_namespace("RecentChanges")

-- timers[bufnr] = uv_timer_t
local timers = {}

local defaults = {
  ttl_ms = 10000,
  max_lines = 200,
  hl_group = "RecentChange",
  exclude_filetypes = {
    opencode_terminal = true,
    opencode_ask = true,
    snacks_terminal = true,
  },
}

-- Gate flashing to only opencode-driven reloads.
-- expected_paths[abs_path] = expires_at_ms
local expected_paths = {}

local function now_ms()
  return uv.now()
end

local function normalize_path(path)
  if type(path) ~= "string" or path == "" then
    return nil
  end

  local abs = vim.fn.fnamemodify(path, ":p")
  if abs == "" then
    return nil
  end
  if vim.fs and vim.fs.normalize then
    abs = vim.fs.normalize(abs)
  end
  return abs
end

local function prune_expected_paths()
  local n = now_ms()
  for p, expires in pairs(expected_paths) do
    if type(expires) ~= "number" or expires <= n then
      expected_paths[p] = nil
    end
  end
end

---Mark a path as expected to change soon (opencode edit).
---@param path string
---@param ttl_ms? number
function M.expect(path, ttl_ms)
  local p = normalize_path(path)
  if not p then
    return
  end
  prune_expected_paths()
  ttl_ms = tonumber(ttl_ms) or 2000
  expected_paths[p] = now_ms() + ttl_ms
end

---Check whether a buffer's file path is currently expected to reload.
---@param buf integer
---@return boolean
function M.is_expected_buf(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end
  prune_expected_paths()
  local p = normalize_path(vim.api.nvim_buf_get_name(buf))
  if not p then
    return false
  end
  local expires = expected_paths[p]
  return type(expires) == "number" and expires > now_ms()
end

---Like is_expected_buf(), but consumes the expectation.
---@param buf integer
---@return boolean
function M.consume_expected_buf(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end
  prune_expected_paths()
  local p = normalize_path(vim.api.nvim_buf_get_name(buf))
  if not p then
    return false
  end
  local expires = expected_paths[p]
  if type(expires) == "number" and expires > now_ms() then
    expected_paths[p] = nil
    return true
  end
  expected_paths[p] = nil
  return false
end

local function is_normal_file_buf(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end
  if vim.api.nvim_get_option_value("buftype", { buf = buf }) ~= "" then
    return false
  end
  if vim.api.nvim_buf_get_name(buf) == "" then
    return false
  end
  local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
  if ft ~= "" and defaults.exclude_filetypes[ft] then
    return false
  end
  return true
end

function M.setup_highlight()
  -- A safe default that works across colorschemes.
  vim.api.nvim_set_hl(0, "RecentChange", { link = "DiffText", default = true })
end

local function stop_timer(buf)
  local t = timers[buf]
  if t then
    t:stop()
    t:close()
    timers[buf] = nil
  end
end

local function clear_highlight(buf)
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  end
end

local function clear_later(buf, ttl_ms)
  stop_timer(buf)
  local t = uv.new_timer()
  timers[buf] = t
  t:start(ttl_ms, 0, vim.schedule_wrap(function()
    clear_highlight(buf)
    stop_timer(buf)
  end))
end

local function apply_hunks(buf, hunks, opts)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  clear_highlight(buf)

  local highlighted = 0
  for _, h in ipairs(hunks) do
    local _a_start, _a_count, b_start, b_count = h[1], h[2], h[3], h[4]
    if b_count and b_count > 0 then
      -- vim.diff indices are 1-based line numbers.
      local from0 = math.max(0, b_start - 1)
      local to0 = from0 + b_count - 1

      for l = from0, to0 do
        vim.api.nvim_buf_set_extmark(buf, ns, l, 0, {
          line_hl_group = opts.hl_group,
          priority = 200,
        })
        highlighted = highlighted + 1
        if highlighted >= opts.max_lines then
          clear_later(buf, opts.ttl_ms)
          return
        end
      end
    end
  end

  if highlighted > 0 then
    clear_later(buf, opts.ttl_ms)
  end
end

---Capture the buffer contents before an external reload.
---Used with FileChangedShell/FileChangedShellPost.
---@param buf integer
---@param opts? table
function M.capture(buf, opts)
  if not is_normal_file_buf(buf) then
    return
  end
  opts = vim.tbl_deep_extend("force", {}, defaults, opts or {})

  -- Store text snapshot to diff against after reload.
  vim.b[buf].recent_changes_opts = opts
  vim.b[buf].recent_changes_prev_text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end

---Diff the last captured text against the current buffer and flash changed lines.
---@param buf integer
function M.flash(buf)
  if not is_normal_file_buf(buf) then
    return
  end

  local prev = vim.b[buf].recent_changes_prev_text
  if type(prev) ~= "string" then
    return
  end

  local opts = vim.b[buf].recent_changes_opts
  opts = vim.tbl_deep_extend("force", {}, defaults, type(opts) == "table" and opts or {})

  local curr = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
  if curr == prev then
    return
  end

  local hunks = vim.diff(prev, curr, { result_type = "indices", ctxlen = 0 })
  apply_hunks(buf, hunks, opts)
end

function M.cleanup(buf)
  stop_timer(buf)
  clear_highlight(buf)
end

M.is_normal_file_buf = is_normal_file_buf

return M
