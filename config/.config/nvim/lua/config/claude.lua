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

-- Buffer terminal de l'agent (nil si aucun) : lu par le garde-fou TermClose (ai_tab).
M.term_buf = function()
  return buf_is_valid() and state.bufnr or nil
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

-- `launch` (optionnel) : { last = bool, prompt = string }. Commande en liste d'arguments
-- (aucun shell : le prompt est transmis tel quel).
local function start_job(buf, launch)
  local cmd = vim.split(CLAUDE_CMD, " ", { plain = true })
  if launch and launch.prompt and launch.prompt ~= "" then
    -- prompt fourni : on execute (mode auto) au lieu de planifier ; lancement initial seulement
    for i, a in ipairs(cmd) do
      if a == "plan" then
        cmd[i] = "auto"
      end
    end
  end
  if launch and launch.last then
    table.insert(cmd, "--continue")
  end
  if launch and launch.prompt and launch.prompt ~= "" then
    if launch.prompt:sub(1, 1) == "-" then
      table.insert(cmd, "--")
    end
    table.insert(cmd, launch.prompt)
  end
  local job
  job = vim.fn.jobstart(cmd, {
    term    = true,
    buffer  = buf,
    on_exit = function()
      if state.job_id ~= job then return end -- terminal deja remplace (reprise echouee)
      state.job_id = nil
      state.bufnr  = nil
      state.winid  = nil
      state.tabwin = nil
    end,
  })
  state.job_id = job
end

-- Reprise (--continue) sortie aussitot en erreur : pas de conversation a reprendre ici.
-- On relance une session neuve dans la meme fenetre (split ou onglet), sans --continue.
local create_terminal -- defini plus bas
local function resume_fallback(old_buf)
  vim.notify("Aucune session à reprendre ici : nouvelle session", vim.log.levels.WARN)
  if buf_is_valid() and state.bufnr ~= old_buf then
    return -- un autre terminal a ete lance entre-temps
  end
  local win = vim.fn.win_findbuf(old_buf)[1]
  if not win then
    state.bufnr, state.job_id, state.winid, state.tabwin = nil, nil, nil, nil
    pcall(vim.api.nvim_buf_delete, old_buf, { force = true })
    M.toggle()
    return
  end
  local ok, mark = pcall(vim.api.nvim_tabpage_get_var, vim.api.nvim_win_get_tabpage(win), "ai_tab")
  local is_tab = ok and mark == "claude"
  state.bufnr, state.job_id, state.winid, state.tabwin = nil, nil, nil, nil
  create_terminal(function(buf)
    vim.api.nvim_win_set_buf(win, buf)
    return win
  end)
  if is_tab then
    state.tabwin = win
  else
    state.winid = win
  end
  pcall(vim.api.nvim_buf_delete, old_buf, { force = true })
  if is_tab and vim.api.nvim_get_current_win() == win then
    vim.cmd("startinsert")
  end
end

-- Create the terminal buffer (hidden-safe), its autocmds, and start the job.
-- `open_win(buf)` must make a window showing `buf` the current one and return
-- it; `on_created(buf)` (optional) runs before the job starts.
create_terminal = function(open_win, on_created, launch)
  local buf = vim.api.nvim_create_buf(false, false) -- non liste : <leader>bo / :bnext n'y touchent pas
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

  start_job(buf, launch)

  if launch and launch.last and not (launch.prompt and launch.prompt ~= "") then
    require("config.ai_tab").watch_launch(buf, function() resume_fallback(buf) end)
  end

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
-- launch (optionnel, 1re creation seulement) : { last = true } reprend la derniere session.
M.toggle = function(launch)
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
    end, launch)
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
-- opts (seulement si le terminal n'existe pas encore) : last = true reprend la derniere
-- conversation (claude --continue) ; prompt = message initial.
M.toggle_tab = function(opts)
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
    end, nil, opts)
  end
  state.tabwin = win
  vim.t.ai_tab = "claude"
  require("config.ai_tab").show_tree(win)
end

-- Reprend la derniere session (claude --continue) dans le split (where = "split") ou
-- l'onglet agent (where = "tab"). Terminal deja vivant : on l'affiche sans le tuer.
M.resume = function(where)
  if buf_is_valid() and state.job_id then
    vim.notify("Session déjà ouverte (pas de reprise)", vim.log.levels.INFO)
    if where == "tab" then
      local tab = find_ai_tab()
      if not (tab and tab == vim.api.nvim_get_current_tabpage()) then
        M.toggle_tab()
      end
    elseif not win_is_valid() then
      M.toggle()
    end
    return
  end
  if where == "tab" then
    M.toggle_tab({ last = true })
  else
    M.toggle({ last = true })
  end
end

-- ---------------------------------------------------------------------------
-- Send text into the live terminal
-- ---------------------------------------------------------------------------

-- Send `text` to the running Claude terminal (as if the user typed it).
-- Automatically opens the split if it is not visible.
-- opts.submit == false : n'ajoute pas le "\n" final (le texte reste dans le prompt, non valide).
M.send = function(text, opts)
  local tail = (opts and opts.submit == false) and "" or "\n"
  if not buf_is_valid() then
    M.toggle()
    -- Wait for the terminal job to start before sending.
    -- 1200ms is conservative but avoids a race condition where chansend
    -- fires before the claude process has initialised its input loop.
    vim.defer_fn(function()
      if state.job_id then
        vim.fn.chansend(state.job_id, text .. tail)
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
    vim.fn.chansend(state.job_id, text .. tail)
  end
end

-- Envoie une reference de fichier ("@chemin ") SANS valider, puis place l'utilisateur dans le
-- terminal Claude (onglet agent s'il existe, sinon split) pour qu'il complete sa question.
-- Sans terminal vivant : lance Claude dans l'onglet agent et envoie une fois le delai de M.send ecoule.
M.send_ref = function(text)
  local function focus()
    vim.schedule(function() -- apres le retour de focus differe de M.send (split)
      local ai = find_ai_tab()
      if ai then
        vim.api.nvim_set_current_tabpage(ai)
        local win = require("config.ai_tab").ensure_terminal(ai, state.bufnr)
        if win then
          vim.api.nvim_set_current_win(win)
          vim.cmd("startinsert")
        end
      elseif win_is_valid() then
        vim.api.nvim_set_current_win(state.winid)
        vim.cmd("startinsert")
      end
    end)
  end
  if buf_is_valid() and state.job_id then
    M.send(text, { submit = false })
    focus()
    return
  end
  close_ai_tab() -- onglet perime eventuel : on repart d'un onglet neuf
  M.toggle_tab()
  vim.defer_fn(function()
    if state.job_id then
      M.send(text, { submit = false })
      focus()
    end
  end, 1200)
end

-- Lance une tache depuis un prompt saisi : sans terminal vivant, ouvre l'onglet agent avec
-- ce prompt (mode auto) ; sinon l'envoie a la session existante et affiche l'onglet agent.
M.run_task = function()
  vim.ui.input({ prompt = "Tâche Claude : " }, function(input)
    if not input or vim.trim(input) == "" then
      return
    end
    local ai_tab = require("config.ai_tab")
    local tab = find_ai_tab()
    if not (buf_is_valid() and state.job_id) then
      if not tab then
        M.toggle_tab({ prompt = input })
        return
      end
      -- onglet agent perime (plus de terminal vivant) : on le reutilise, sans le fermer
      vim.api.nvim_set_current_tabpage(tab)
      local win = ai_tab.main_win(tab)
      if not win then
        vim.notify("Claude : aucune fenêtre disponible. Texte : " .. input, vim.log.levels.ERROR)
        return
      end
      vim.api.nvim_set_current_win(win)
      create_terminal(function(buf)
        vim.api.nvim_win_set_buf(win, buf)
        return win
      end, nil, { prompt = input })
      state.tabwin = win
      vim.cmd("startinsert")
      return
    end
    if tab then
      vim.api.nvim_set_current_tabpage(tab)
      local win = ai_tab.ensure_terminal(tab, state.bufnr)
      if win then
        vim.api.nvim_set_current_win(win)
        vim.cmd("startinsert")
      end
    else
      M.toggle_tab() -- cree l'onglet avec le terminal existant
    end
    M.send(input)
    vim.notify("Session existante : message envoyé, mode inchangé", vim.log.levels.INFO)
  end)
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

  -- <leader>zl / zL  Reprendre la derniere session (split / onglet)
  vim.keymap.set("n", "<leader>zl", function()
    M.resume("split")
  end, { desc = "Claude: reprendre la dernière session (split)" })
  vim.keymap.set("n", "<leader>zL", function()
    M.resume("tab")
  end, { desc = "Claude: reprendre la dernière session (onglet)" })

  -- <leader>zr  Envoyer une reference (@fichier ou @fichier#L10-25), sans valider
  vim.keymap.set({ "n", "x" }, "<leader>zr", function()
    local ref = require("config.ai_tab").file_ref()
    if ref then
      M.send_ref(ref)
    end
  end, { desc = "Claude: référence du fichier / de la sélection" })

  -- <leader>zP  Tache (prompt) : nouvelle session en mode auto, ou envoi a la session existante
  vim.keymap.set("n", "<leader>zP", function()
    M.run_task()
  end, { desc = "Claude: tâche (prompt, auto)" })

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
