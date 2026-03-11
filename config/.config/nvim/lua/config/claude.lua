-- Claude Code Neovim Integration
-- Inspired by opencode.nvim terminal module

local M = {}

-- Module-level state — persists for the lifetime of Neovim
local state = {
  winid  = nil,  -- current window (nil when hidden)
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
    end,
  })
end

-- ---------------------------------------------------------------------------
-- Core toggle
-- ---------------------------------------------------------------------------

-- Three states:
--   1. bufnr == nil          → first launch: create buf + win + job
--   2. buf valid, win visible → hide the window (session preserved)
--   3. buf valid, win hidden  → re-show window + re-enter insert + return focus
M.toggle = function()
  local previous_win = vim.api.nvim_get_current_win()

  -- State 1 — first launch
  if not buf_is_valid() then
    state.bufnr = vim.api.nvim_create_buf(true, false)
    vim.bo[state.bufnr].bufhidden = "hide"  -- keep alive when window closes

    state.winid = open_split(state.bufnr)

    -- Setup autoinsert + focus return before starting the job
    setup_autoinsert(state.bufnr, previous_win)

    -- Setup local keymaps once the buffer becomes a terminal
    vim.api.nvim_create_autocmd("TermOpen", {
      buffer = state.bufnr,
      once   = true,
      callback = function()
        setup_terminal_keymaps(state.bufnr)
      end,
    })

    start_job(state.bufnr)

    -- Kill the job cleanly when Neovim exits
    vim.api.nvim_create_autocmd("ExitPre", {
      once = true,
      callback = function()
        if state.job_id then
          vim.fn.jobstop(state.job_id)
        end
      end,
    })

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
  if not win_is_valid() then
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

  -- ============================================
  -- CLAUDE KEYMAPS  (prefix <leader>z)
  -- ============================================

  -- <leader>zt  Toggle split (focus stays in code window)
  vim.keymap.set({ "n", "t" }, "<leader>zt", function()
    M.toggle()
  end, { desc = "Claude: Toggle split" })

  -- <leader>zh  Jump INTO the Claude split in insert mode
  vim.keymap.set("n", "<leader>zh", function()
    if not buf_is_valid() then
      M.toggle()
      return
    end
    if not win_is_valid() then
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
  if not M.is_available() then
    vim.notify(
      "claude: CLI not found – run ./script/install-claude",
      vim.log.levels.WARN
    )
  end
end

return M
