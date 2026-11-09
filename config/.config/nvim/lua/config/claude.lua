-- Claude Code Neovim Integration
-- Inspired by opencode.nvim terminal module

local M = {}

-- Module-level state — persists for the lifetime of Neovim
local state = {
  winid  = nil,  -- split window (nil when hidden)
  tabwin = nil,  -- window of the dedicated Claude tab (nil when no tab)
  bufnr  = nil,  -- terminal buffer (kept alive between hide/show)
  job_id = nil,  -- terminal job id (for chansend + jobstop)
}

local CLAUDE_CMD = "claude --permission-mode plan"
local SPLIT_WIDTH_RATIO = 0.40  -- 40% of editor width

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function win_is_valid()
  return state.winid ~= nil and vim.api.nvim_win_is_valid(state.winid)
end

local function buf_is_valid()
  return state.bufnr ~= nil and vim.api.nvim_buf_is_valid(state.bufnr)
end

-- Open a right-side vertical split showing `buf`, return the new winid.
local function open_split(buf)
  return vim.api.nvim_open_win(buf, true, {
    split  = "right",
    width  = math.floor(vim.o.columns * SPLIT_WIDTH_RATIO),
  })
end

-- After the terminal renders its first line, switch to insert mode then
-- immediately return focus to the previous (code) window — exactly like
-- opencode.nvim so the user can keep editing while Claude is ready.
local function setup_autoinsert(buf, previous_win)
  local auid
  auid = vim.api.nvim_create_autocmd("TermRequest", {
    buffer = buf,
    callback = function(ev)
      if ev.data and ev.data.cursor and ev.data.cursor[1] > 1 then
        vim.api.nvim_del_autocmd(auid)
        -- Enter insert in the Claude window, then jump back to code window.
        vim.cmd("startinsert")
        vim.fn.feedkeys(vim.api.nvim_replace_termcodes(
          "<C-\\><C-n>", true, false, true), "n")
        if previous_win and vim.api.nvim_win_is_valid(previous_win) then
          vim.api.nvim_set_current_win(previous_win)
        end
      end
    end,
  })
end

-- Apply buffer-local keymaps once the buffer becomes a real terminal.
local function setup_terminal_keymaps(buf)
  local opts = { buffer = buf, noremap = true, silent = true }

  -- <Esc> → interrupt Claude (Ctrl-C)
  vim.keymap.set("t", "<Esc>", function()
    if state.job_id then
      vim.fn.chansend(state.job_id, "\x03")
    end
  end, vim.tbl_extend("force", opts, { desc = "Claude: Interrupt" }))

  -- <C-w>p → leave terminal, go back to previous code window
  vim.keymap.set("t", "<C-w>p", function()
    vim.fn.feedkeys(vim.api.nvim_replace_termcodes(
      "<C-\\><C-n><C-w>p", true, false, true), "n")
  end, vim.tbl_extend("force", opts, { desc = "Claude: Focus code window" }))

  -- <C-w>h → same, explicit left split
  vim.keymap.set("t", "<C-w>h", function()
    vim.fn.feedkeys(vim.api.nvim_replace_termcodes(
      "<C-\\><C-n><C-w>h", true, false, true), "n")
  end, vim.tbl_extend("force", opts, { desc = "Claude: Focus left window" }))
end

-- ---------------------------------------------------------------------------
-- Job management
-- ---------------------------------------------------------------------------

local function start_job(buf)
  state.job_id = vim.fn.jobstart(CLAUDE_CMD, {
    term    = true,
    buffer  = buf,
    on_exit = function()
      state.job_id = nil
      state.bufnr  = nil
      state.winid  = nil
      state.tabwin = nil
    end,
  })
end

-- Create the terminal buffer (hidden-safe), its autocmds, and start the job.
-- `open_win(buf)` must make a window showing `buf` the current one and return
-- it; `on_created(buf)` (optional) runs before the job starts.
local function create_terminal(open_win, on_created)
  local buf = vim.api.nvim_create_buf(true, false)
  state.bufnr = buf
  vim.bo[buf].bufhidden = "hide"  -- keep alive when window closes

  local win = open_win(buf)

  if on_created then on_created(buf) end

  -- Setup local keymaps once the buffer becomes a terminal
  vim.api.nvim_create_autocmd("TermOpen", {
    buffer = buf,
    once   = true,
    callback = function()
      setup_terminal_keymaps(buf)
    end,
  })

  start_job(buf)

  -- Kill the job cleanly when Neovim exits
  vim.api.nvim_create_autocmd("ExitPre", {
    once = true,
    callback = function()
      if state.job_id then
        vim.fn.jobstop(state.job_id)
      end
    end,
  })

  return buf, win
end

-- ---------------------------------------------------------------------------
-- Dedicated tab (tabpage marked with vim.t.ai_tab == "claude")
-- ---------------------------------------------------------------------------

local function find_ai_tab()
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local ok, v = pcall(vim.api.nvim_tabpage_get_var, tab, "ai_tab")
    if ok and v == "claude" then
      return tab
    end
  end
end

-- Close the Claude tab if any. The terminal buffer survives (bufhidden=hide).
local function close_ai_tab()
  local tab = find_ai_tab()
  if not tab then return end
  state.tabwin = nil
  if #vim.api.nvim_list_tabpages() > 1 then
    vim.cmd("tabclose " .. vim.api.nvim_tabpage_get_number(tab))
    return
  end
  -- Last tab: cannot tabclose; swap the terminal for another buffer so it is no
  -- longer displayed, but stays alive.
  require("config.ai_tab").release_last_tab(tab, state.bufnr)
end

-- ---------------------------------------------------------------------------
-- Core toggle
-- ---------------------------------------------------------------------------

-- Three states:
--   1. bufnr == nil          → first launch: create buf + win + job
--   2. buf valid, win visible → hide the window (session preserved)
--   3. buf valid, win hidden  → re-show window + re-enter insert + return focus
M.toggle = function()
  -- Only one display at a time: showing the split closes the Claude tab.
  if not (buf_is_valid() and win_is_valid()) then
    close_ai_tab()
  end
  local previous_win = vim.api.nvim_get_current_win()

  -- State 1 — first launch
  if not buf_is_valid() then
    create_terminal(function(buf)
      state.winid = open_split(buf)
      return state.winid
    end, function(buf)
      -- Setup autoinsert + focus return before starting the job
      setup_autoinsert(buf, previous_win)
    end)
    return
  end

  -- State 2 — window is visible → hide it
  if win_is_valid() then
    vim.api.nvim_win_hide(state.winid)
    state.winid = nil
    return
  end

  -- State 3 — buffer exists but window is hidden → re-show
  state.winid = open_split(state.bufnr)

  -- Re-enter insert in Claude, then return focus to code window.
  -- Small schedule so the window has time to render.
  vim.schedule(function()
    if win_is_valid() then
      vim.api.nvim_set_current_win(state.winid)
      vim.cmd("startinsert")
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes(
        "<C-\\><C-n>", true, false, true), "n")
      if vim.api.nvim_win_is_valid(previous_win) then
        vim.api.nvim_set_current_win(previous_win)
      end
    end
  end)
end

-- Toggle the Claude terminal in a dedicated fullscreen tab (same buffer as the
-- split). Focus stays in the terminal.
--   1. current tab is the Claude tab → close it
--   2. a Claude tab exists elsewhere → jump to it
--   3. otherwise → hide the split, open a new tab showing the terminal
M.toggle_tab = function()
  local tab = find_ai_tab()
  if tab and tab == vim.api.nvim_get_current_tabpage() then
    close_ai_tab()
    return
  end
  if tab then
    vim.api.nvim_set_current_tabpage(tab)
    local win = require("config.ai_tab").ensure_terminal(tab, state.bufnr)
    if win then
      vim.api.nvim_set_current_win(win)
      vim.cmd("startinsert")
    end
    return
  end

  -- Never show split and tab together (the TUI would shrink to the smaller one)
  if win_is_valid() then
    pcall(vim.api.nvim_win_hide, state.winid)
    state.winid = nil
  end

  vim.cmd("tabnew")
  local win = vim.api.nvim_get_current_win()
  local empty = vim.api.nvim_get_current_buf()
  vim.bo[empty].bufhidden = "wipe"  -- don't leave the [No Name] buffer behind

  if buf_is_valid() then
    vim.api.nvim_win_set_buf(win, state.bufnr)
  else
    create_terminal(function(buf)
      vim.api.nvim_win_set_buf(win, buf)
      return win
    end)
  end
  state.tabwin = win
  vim.t.ai_tab = "claude"
  require("config.ai_tab").show_tree(win)
end

-- ---------------------------------------------------------------------------
-- Send text into the live terminal
-- ---------------------------------------------------------------------------

-- Send `text` to the running Claude terminal (as if the user typed it).
-- Automatically opens the split if it is not visible.
M.send = function(text)
  if not buf_is_valid() then
    M.toggle()
    -- Wait for the terminal job to start before sending.
    -- 1200ms is conservative but avoids a race condition where chansend
    -- fires before the claude process has initialised its input loop.
    vim.defer_fn(function()
      if state.job_id then
        vim.fn.chansend(state.job_id, text .. "\n")
      end
    end, 1200)
    return
  end

  -- Ensure the window is visible so the user sees the interaction
  -- (the Claude tab, if open, already shows the terminal: no extra split)
  local ai = find_ai_tab()
  if ai then
    require("config.ai_tab").ensure_terminal(ai, state.bufnr)
  elseif not win_is_valid() then
    local previous_win = vim.api.nvim_get_current_win()
    state.winid = open_split(state.bufnr)
    vim.schedule(function()
      if vim.api.nvim_win_is_valid(previous_win) then
        vim.api.nvim_set_current_win(previous_win)
      end
    end)
  end

  if state.job_id then
    vim.fn.chansend(state.job_id, text .. "\n")
  end
end

-- Send the contents of `path` as a single message. Used by the voice-to-claude
-- pipeline to avoid shell-quoting issues with transcribed text (apostrophes,
-- quotes, newlines).
M.send_from_file = function(path)
  local f = io.open(path, "r")
  if not f then return end
  local text = f:read("*a")
  f:close()
  if text and #text > 0 then
    M.send(text)
  end
end

-- ---------------------------------------------------------------------------
-- Public helpers
-- ---------------------------------------------------------------------------

M.is_available = function()
  return vim.fn.executable("claude") == 1
end

-- Return the visually selected text (works in visual mode).
local function get_visual_selection()
  -- Save and restore register
  local reg_save = vim.fn.getreg('"')
  vim.cmd('noau normal! y')
  local text = vim.fn.getreg('"')
  vim.fn.setreg('"', reg_save)
  return text
end

-- ---------------------------------------------------------------------------
-- Setup — keymaps + init
-- ---------------------------------------------------------------------------

M.setup = function()

  -- Make module reachable from anywhere for debugging
  _G.claude_nvim = M

  -- Advertise this nvim's socket to external tools (voice-to-claude).
  -- The last-focused nvim instance wins, so the dictation always targets
  -- whichever window the user is currently working in.
  local socket_dir  = (vim.env.XDG_RUNTIME_DIR or "/tmp") .. "/voice-to-claude"
  local socket_file = socket_dir .. "/nvim-socket"
  vim.fn.mkdir(socket_dir, "p")
  local function advertise_socket()
    if vim.v.servername and #vim.v.servername > 0 then
      local fd = io.open(socket_file, "w")
      if fd then fd:write(vim.v.servername); fd:close() end
    end
  end
  advertise_socket()
  vim.api.nvim_create_autocmd({ "VimEnter", "FocusGained" }, {
    callback = advertise_socket,
  })

  -- ============================================
  -- CLAUDE KEYMAPS  (prefix <leader>z)
  -- ============================================

  -- <leader>zt  Toggle split (focus stays in code window)
  vim.keymap.set({ "n", "t" }, "<leader>zt", function()
    M.toggle()
  end, { desc = "Claude: Toggle split" })

  -- <leader>zT  Toggle dedicated tab (focus goes into the terminal)
  vim.keymap.set({ "n", "t" }, "<leader>zT", function()
    M.toggle_tab()
  end, { desc = "Claude: Toggle onglet" })

  -- <leader>zh  Jump INTO the Claude split in insert mode
  vim.keymap.set("n", "<leader>zh", function()
    if not buf_is_valid() then
      M.toggle()
      return
    end
    if not win_is_valid() then
      close_ai_tab()
      state.winid = open_split(state.bufnr)
    end
    vim.api.nvim_set_current_win(state.winid)
    vim.cmd("startinsert")
  end, { desc = "Claude: Focus split (insert)" })

  -- <leader>za  Send visual selection (or prompt for input) to Claude
  vim.keymap.set("n", "<leader>za", function()
    vim.ui.input({ prompt = "Ask Claude: " }, function(input)
      if input and #input > 0 then
        M.send(input)
      end
    end)
  end, { desc = "Claude: Ask (input)" })

  vim.keymap.set("x", "<leader>za", function()
    local sel = get_visual_selection()
    if sel and #sel > 0 then
      vim.ui.input({ prompt = "Ask about selection: " }, function(input)
        local msg = input and #input > 0
          and (input .. "\n\n```\n" .. sel .. "\n```")
          or sel
        M.send(msg)
      end)
    end
  end, { desc = "Claude: Ask about selection" })

  -- <leader>zb  Send current buffer to Claude
  vim.keymap.set("n", "<leader>zb", function()
    local ft      = vim.bo.filetype
    local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
    vim.ui.input({ prompt = "Ask about buffer: " }, function(input)
      if input and #input > 0 then
        local msg = input .. "\n\n```" .. ft .. "\n" .. content .. "\n```"
        M.send(msg)
      end
    end)
  end, { desc = "Claude: Send buffer" })

  -- <leader>zp  Send visual selection as a plain paste (no extra prompt)
  vim.keymap.set("x", "<leader>zp", function()
    local sel = get_visual_selection()
    if sel and #sel > 0 then
      M.send("```\n" .. sel .. "\n```")
    end
  end, { desc = "Claude: Paste selection" })

  -- ---------------------------------------------------------------------------
  -- Rappel optionnel : mets `vim.g.claude_warn_missing = true` si tu veux
  -- etre averti au demarrage que le CLI Claude n'est pas installe.
  if vim.g.claude_warn_missing and not M.is_available() then
    vim.notify(
      "claude: CLI not found – run ./script/install-claude",
      vim.log.levels.WARN
    )
  end
end

return M
