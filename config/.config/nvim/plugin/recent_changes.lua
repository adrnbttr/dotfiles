-- Flash lines changed by external edits (opencode or others).
-- Loaded on startup (not on VeryLazy).

local ok, recent = pcall(require, "config.recent_changes")
if not ok then
  return
end

local uv = vim.uv or vim.loop

recent.setup_highlight()

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = recent.setup_highlight,
})

-- Only flash for edits coming from opencode.
-- opencode.nvim reloads buffers via :checktime after this event.
vim.api.nvim_create_autocmd("User", {
  pattern = "OpencodeEvent:file.edited",
  callback = function(args)
    local ev = args and args.data and args.data.event
    local file = ev and ev.properties and ev.properties.file
    if type(file) == "string" and file ~= "" then
      recent.expect(file)
    end
  end,
})

-- File watchers: watchers[filepath] = uv_fs_event_t
local watchers = {}
local buf_content_before = {}

-- Stop watching a file
local function stop_watching(filepath)
  local w = watchers[filepath]
  if w then
    w:stop()
    w:close()
    watchers[filepath] = nil
  end
end

-- Start watching a buffer's file
local function start_watching(bufnr, filepath)
  if not filepath or filepath == "" then
    return
  end
  
  -- Stop any existing watcher for this file
  stop_watching(filepath)
  
  local w = uv.new_fs_event()
  if not w then
    return
  end
  
  watchers[filepath] = w
  
  w:start(filepath, {}, vim.schedule_wrap(function(err, filename, events)
    if err then
      return
    end
    
    -- Check if buffer is still valid
    if not vim.api.nvim_buf_is_valid(bufnr) then
      stop_watching(filepath)
      return
    end
    
    -- Store content before reload
    buf_content_before[bufnr] = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
    
    -- Reload the buffer (even without focus)
    vim.api.nvim_buf_call(bufnr, function()
      vim.cmd("checktime")
    end)
  end))
end

-- Setup file watching for buffers
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  callback = function(ev)
    if recent.is_normal_file_buf(ev.buf) then
      local filepath = vim.api.nvim_buf_get_name(ev.buf)
      if filepath and filepath ~= "" then
        start_watching(ev.buf, filepath)
      end
    end
  end,
})

-- Check for changes after file is reloaded
vim.api.nvim_create_autocmd({ "BufReadPost", "FileChangedShellPost" }, {
  callback = function(ev)
    if not recent.is_normal_file_buf(ev.buf) then
      return
    end
    
    local before = buf_content_before[ev.buf]
    buf_content_before[ev.buf] = nil
    
    if before then
      local after = table.concat(vim.api.nvim_buf_get_lines(ev.buf, 0, -1, false), "\n")
      if before ~= after then
        -- Content changed, flash it
        vim.b[ev.buf].recent_changes_prev_text = before
        vim.b[ev.buf].recent_changes_opts = nil
        recent.flash(ev.buf)
      end
    end
  end,
})

-- Clean up on buffer close
vim.api.nvim_create_autocmd({ "BufWipeout", "BufUnload" }, {
  callback = function(ev)
    recent.cleanup(ev.buf)
    buf_content_before[ev.buf] = nil
    
    -- Stop watching this buffer's file
    local filepath = vim.api.nvim_buf_get_name(ev.buf)
    if filepath and filepath ~= "" then
      stop_watching(filepath)
    end
  end,
})
