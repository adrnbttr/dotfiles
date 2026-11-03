-- Fenetre flottante de relecture d'une dictee : le texte est editable, en mode normal.
-- Rien ne part sans une touche explicite : <C-s> (normal et insert) ou <leader><CR>.
-- q / <Esc> (normal) ferment sans envoyer et copient le texte final dans le presse-papiers.

local M = {}

local function copy(text)
  pcall(vim.fn.setreg, "+", text)
  pcall(vim.fn.setreg, '"', text)
end

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Dictee" })
end

--- Ouvre la fenetre. opts.send(text, cb) envoie ; cb(ok, err) est rappele a la fin ;
--- opts.on_sent() est appele apres un envoi reussi ; opts.on_fail(err) apres un echec
--- (la fenetre reste ouverte).
---@param text string
---@param opts { send: fun(text: string, cb: fun(ok: boolean, err: string?)), on_sent?: fun(), on_fail?: fun(err: string?) }
function M.open(text, opts)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, "\n", { plain = true }))

  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " Dictee : <C-s> ou <leader><CR> envoie | q ferme (copie) ",
    title_pos = "center",
  })
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.cmd("stopinsert") -- toujours en NORMAL : une frappe parasite ne peut rien envoyer

  local sending = false

  local function current_text()
    return vim.trim(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"))
  end

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  local function send()
    if sending then
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
    sending = true
    opts.send(final, function(ok, err)
      sending = false
      if ok then
        close()
        if opts.on_sent then opts.on_sent() end
      else
        if opts.on_fail then opts.on_fail(err) end
        -- on_fail peut avoir ouvert le terminal : rendre le focus a la relecture
        if vim.api.nvim_win_is_valid(win) then vim.api.nvim_set_current_win(win) end
      end
    end)
  end

  local function dismiss()
    copy(current_text())
    close()
    notify("Dictée non envoyée, copiée dans le presse-papiers")
  end

  local o = { buffer = buf, nowait = true }
  vim.keymap.set({ "n", "i" }, "<C-s>", send, vim.tbl_extend("force", o, { desc = "Envoyer la dictee" }))
  vim.keymap.set("n", "<leader><CR>", send, vim.tbl_extend("force", o, { desc = "Envoyer la dictee" }))
  vim.keymap.set("n", "q", dismiss, vim.tbl_extend("force", o, { desc = "Fermer sans envoyer" }))
  vim.keymap.set("n", "<Esc>", dismiss, vim.tbl_extend("force", o, { desc = "Fermer sans envoyer" }))
end

return M
