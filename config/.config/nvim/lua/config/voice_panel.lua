-- Panneau de dictee en direct : un split sous le terminal opencode ou le texte s'ecrit pendant
-- qu'on parle (M.append), avec l'etat du micro dans la winbar (M.status).
-- Rien ne part sans une touche explicite, et seulement apres M.review() : <Esc> (normal) ou
-- <C-s> (normal et insert) envoient, q ferme sans envoyer en copiant le texte.
-- En insert, <Esc> ne fait que revenir en normal. Pendant l'ecoute aucune touche n'envoie.

local M = {}

local HEIGHT = 8

local state -- { buf, win, phase = "listening"|"review", sending, closing, opts }

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Dictee" })
end

local function copy(text)
  pcall(vim.fn.setreg, "+", text)
  pcall(vim.fn.setreg, '"', text)
end

local function set_hl()
  vim.api.nvim_set_hl(0, "VoicePanelListen", { default = true, link = "DiagnosticOk" })
  vim.api.nvim_set_hl(0, "VoicePanelWarn", { default = true, link = "DiagnosticWarn" })
  vim.api.nvim_set_hl(0, "VoicePanelBusy", { default = true, link = "DiagnosticInfo" })
  vim.api.nvim_set_hl(0, "VoicePanelReview", { default = true, link = "DiagnosticHint" })
end

local function winbar(group, text)
  if state and vim.api.nvim_win_is_valid(state.win) then
    vim.wo[state.win].winbar = "%#" .. group .. "# " .. text:gsub("%%", "%%%%") .. " %*"
  end
end

local function current_text()
  if not (state and vim.api.nvim_buf_is_valid(state.buf)) then
    return ""
  end
  return vim.trim(table.concat(vim.api.nvim_buf_get_lines(state.buf, 0, -1, false), "\n"))
end

local function close_quiet()
  if not state then
    return
  end
  local s = state
  s.closing = true
  state = nil
  if vim.api.nvim_win_is_valid(s.win) then
    pcall(vim.api.nvim_win_close, s.win, true)
  end
  if vim.api.nvim_buf_is_valid(s.buf) then
    pcall(vim.api.nvim_buf_delete, s.buf, { force = true })
  end
end

--- Ferme le panneau sans notification ni annulation du moteur.
function M.close()
  close_quiet()
end

function M.is_open()
  return state ~= nil and vim.api.nvim_win_is_valid(state.win)
end

--- Contenu actuel du panneau (texte dicte, eventuellement corrige).
function M.text()
  return current_text()
end

--- Ferme par un autre moyen que nos touches (:q, :e, <C-w>c...). Le texte est capture de facon
--- SYNCHRONE (WinClosed / BufUnload / BufWipeout se declenchent avant la destruction du buffer) :
--- une fois le buffer detruit il serait trop tard. Le reste (notification, annulation) est differe.
local function on_external_close(s)
  if state ~= s or s.closing then
    return
  end
  local text = current_text()
  local phase = s.phase
  state = nil
  s.closing = true
  if text ~= "" then
    copy(text)
  end
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(s.buf) then
      pcall(vim.api.nvim_buf_delete, s.buf, { force = true })
    end
    if phase == "listening" then
      pcall(function()
        require("config.voice").cancel()
      end)
      notify("Dictée interrompue, texte copié dans le presse-papiers", vim.log.levels.WARN)
    else
      notify("Dictée non envoyée, copiée dans le presse-papiers")
    end
  end)
end

---@param opts { anchor_win?: integer, send: fun(text: string, cb: fun(ok: boolean, err: string?)), on_sent?: fun(), on_fail?: fun(err: string?) }
function M.open(opts)
  opts = opts or {}
  close_quiet()
  set_hl()

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false

  local anchor = opts.anchor_win
  if not (anchor and vim.api.nvim_win_is_valid(anchor)) then
    anchor = -1 -- bas de l'ecran
  end
  -- enter = false : le focus reste ou il etait
  local win = vim.api.nvim_open_win(buf, false, {
    split = "below",
    win = anchor,
    height = HEIGHT,
  })
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].winfixheight = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].foldcolumn = "0"

  local s = { buf = buf, win = win, phase = "listening", sending = false, closing = false, opts = opts }
  state = s

  -- synchrone : le buffer existe encore (bufhidden = wipe le detruit juste apres)
  local function sync_close()
    on_external_close(s)
  end
  vim.api.nvim_create_autocmd("WinClosed", { pattern = tostring(win), once = true, callback = sync_close })
  vim.api.nvim_create_autocmd({ "BufUnload", "BufWipeout" }, { buffer = buf, once = true, callback = sync_close })

  M.status("starting")
end

function M.append(text)
  if not (state and vim.api.nvim_buf_is_valid(state.buf)) then
    return
  end
  text = vim.trim((text or ""):gsub("%s*\n%s*", " "))
  if text == "" then
    return
  end
  local buf = state.buf
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local last = #lines
  local cur = lines[last] or ""
  if #lines == 1 and cur == "" then
    lines[1] = text
  else
    lines[last] = cur .. " " .. text
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  if vim.api.nvim_win_is_valid(state.win) then
    local n = vim.api.nvim_buf_line_count(buf)
    local l = vim.api.nvim_buf_get_lines(buf, n - 1, n, false)[1] or ""
    pcall(vim.api.nvim_win_set_cursor, state.win, { n, math.max(#l - 1, 0) })
  end
  -- registre " seulement : sous WSL, + passe par clip.exe (lent) ; + est copie a la fin
  pcall(vim.fn.setreg, '"', current_text())
end

---@param st string "starting"|"listening"|"muted"|"reconnecting"|"finishing"|"error"|"review"
---@param info? table
function M.status(st, info)
  info = info or {}
  if st == "error" then
    notify(tostring(info.msg or "erreur micro"), vim.log.levels.WARN)
    return
  end
  if not state or state.phase == "review" and st ~= "review" then
    return
  end
  if st == "starting" then
    winbar("VoicePanelBusy", "◌ Démarrage micro…")
  elseif st == "listening" then
    local e = math.floor(info.elapsed or 0)
    winbar("VoicePanelListen", string.format("● Écoute %d:%02d · Alt+V = fin", math.floor(e / 60), e % 60))
  elseif st == "muted" then
    winbar("VoicePanelWarn", "⚠ Micro muet : wsl --shutdown (Windows) · Alt+V = fin")
  elseif st == "reconnecting" then
    winbar("VoicePanelWarn", "↻ Reconnexion micro…")
  elseif st == "finishing" then
    winbar("VoicePanelBusy", "⏳ Transcription des derniers mots…")
  elseif st == "review" then
    winbar("VoicePanelReview", "Relis · Échap envoie · q annule")
  end
end

local function send()
  local s = state
  if not s or s.phase ~= "review" then
    return
  end
  if s.sending then
    notify("Envoi en cours…", vim.log.levels.WARN)
    return
  end
  local final = current_text()
  if final == "" then
    notify("Texte vide, rien a envoyer", vim.log.levels.WARN)
    return
  end
  final = final:gsub("%.%.%.$", "…")
  copy(final)
  s.sending = true
  s.opts.send(final, function(ok, err)
    s.sending = false
    if ok then
      if state == s then
        close_quiet()
      end
      if s.opts.on_sent then s.opts.on_sent() end
    else
      if s.opts.on_fail then s.opts.on_fail(err or "") end
      -- on_fail peut avoir ouvert le terminal : rendre le focus au panneau
      if state == s and vim.api.nvim_win_is_valid(s.win) then
        vim.api.nvim_set_current_win(s.win)
      end
    end
  end)
end

local function dismiss()
  if not state or state.phase ~= "review" then
    return
  end
  if state.sending then
    notify("Envoi en cours…", vim.log.levels.WARN)
    return
  end
  copy(current_text())
  close_quiet()
  notify("Dictée non envoyée, copiée dans le presse-papiers")
end

--- Passe en relecture : focus dans le panneau, mode normal, touches d'envoi actives.
function M.review()
  if not M.is_open() then
    return
  end
  local s = state
  s.phase = "review"
  copy(current_text())
  M.status("review")
  local o = { buffer = s.buf, nowait = true }
  vim.keymap.set({ "n", "i" }, "<C-s>", send, vim.tbl_extend("force", o, { desc = "Envoyer la dictee" }))
  vim.keymap.set("n", "<Esc>", send, vim.tbl_extend("force", o, { desc = "Envoyer la dictee" }))
  vim.keymap.set("n", "q", dismiss, vim.tbl_extend("force", o, { desc = "Fermer sans envoyer" }))
  vim.api.nvim_set_current_win(s.win)
  vim.cmd("stopinsert") -- toujours en NORMAL : une frappe parasite ne peut rien envoyer
  local n = vim.api.nvim_buf_line_count(s.buf)
  local l = vim.api.nvim_buf_get_lines(s.buf, n - 1, n, false)[1] or ""
  pcall(vim.api.nvim_win_set_cursor, s.win, { n, math.max(#l - 1, 0) })
  copy(current_text())
end

return M
