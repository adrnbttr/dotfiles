-- Page d'accueil : « HELLO » en demi-blocs + curseur fixe, à côté d'une baleine (hello whales).
-- Les lignes du logo sont complétées à la même largeur entre elles (alignées) : le logo reste centré
-- quel que soit le chemin du projet.
-- Le dossier courant et la branche git (`~/chemin (branche)`) s'affichent tout en bas à droite de la
-- fenêtre, dans une petite flottante non focusable (surbrillance SnacksDashboardDesc), fermée dès que
-- le dashboard quitte sa fenêtre. Les raccourcis (keys) et la ligne startup de LazyVim restent dessous.

-- HELLO en demi-blocs (3 lignes, terminé par le curseur fixe ▀▀) à côté d'une petite baleine avec un petit jet d'eau.
local hello = {
  [[                                      ▀▄▀]],
  [[█   █ █▀▀▀▀ █     █     ▄▀▀▀▄       ▄███████▄▄   ▄▄]],
  [[█▀▀▀█ █▀▀▀  █     █     █   █      ██▀█████████▄▀▀]],
  [[▀   ▀ ▀▀▀▀▀ ▀▀▀▀▀ ▀▀▀▀▀  ▀▀▀  ▀▀    ▀█████████▀]],
}

local function git_branch()
  local out = vim.fn.systemlist({ "git", "-C", vim.fn.getcwd(), "branch", "--show-current" })
  if vim.v.shell_error ~= 0 or not out[1] or out[1] == "" then
    return nil
  end
  return out[1]
end

-- Texte « cwd (branche) » affiché dans l'angle bas droit.
local function session_text()
  local session = vim.fn.fnamemodify(vim.fn.getcwd(), ":~")
  local branch = git_branch()
  if branch then
    session = session .. " (" .. branch .. ")"
  end
  return session
end

local function header_sections()
  local width = 0
  for _, l in ipairs(hello) do
    width = math.max(width, vim.fn.strdisplaywidth(l))
  end
  local sections = {}
  for i, l in ipairs(hello) do
    local pad = (" "):rep(width - vim.fn.strdisplaywidth(l))
    sections[i] = { align = "center", text = { { l .. pad, hl = "header" } }, padding = i == #hello and 2 or 0 }
  end
  return sections
end

-- Flottante dans l'angle bas droit de la fenêtre du dashboard : « cwd (branche) ».
-- Une seule à la fois, buffer scratch réutilisé, fermée dès que le dashboard quitte sa fenêtre.
local corner = { win = nil, buf = nil }

local function corner_close()
  if corner.win and vim.api.nvim_win_is_valid(corner.win) then
    pcall(vim.api.nvim_win_close, corner.win, true)
  end
  corner.win = nil
end

local function dashboard_win()
  local cur = vim.api.nvim_get_current_win()
  local wins = { cur }
  vim.list_extend(wins, vim.api.nvim_list_wins())
  for _, w in ipairs(wins) do
    local b = vim.api.nvim_win_get_buf(w)
    if w ~= corner.win and vim.bo[b].filetype == "snacks_dashboard" then
      return w, b
    end
  end
end

local function corner_update()
  local win, buf = dashboard_win()
  if not win then
    return corner_close()
  end
  local w, h = vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_height(win)
  -- Dernière ligne non vide du dashboard (position relative à la fenêtre) : pas de chevauchement.
  local last = 0
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for i = #lines, 1, -1 do
    if lines[i]:match("%S") then
      last = i
      break
    end
  end
  local top = vim.fn.getwininfo(win)[1].topline
  if last - top + 1 >= h or w < 4 then
    return corner_close()
  end

  local text = session_text()
  local max = w - 2
  if vim.fn.strdisplaywidth(text) > max then
    local keep = math.max(max - 1, 1)
    local n = vim.fn.strchars(text)
    while n > 0 and vim.fn.strdisplaywidth(vim.fn.strcharpart(text, vim.fn.strchars(text) - n)) > keep do
      n = n - 1
    end
    text = "…" .. vim.fn.strcharpart(text, vim.fn.strchars(text) - n)
  end
  text = text .. " "

  if not (corner.buf and vim.api.nvim_buf_is_valid(corner.buf)) then
    corner.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[corner.buf].bufhidden = "hide"
  end
  vim.api.nvim_buf_set_lines(corner.buf, 0, -1, false, { text })
  vim.api.nvim_buf_clear_namespace(corner.buf, -1, 0, -1)
  vim.api.nvim_buf_set_extmark(corner.buf, vim.api.nvim_create_namespace("dashboard_corner"), 0, 0, {
    end_col = #text,
    hl_group = "SnacksDashboardDesc",
  })

  local cfg = {
    relative = "win",
    win = win,
    anchor = "SE",
    row = h,
    col = w,
    width = vim.fn.strdisplaywidth(text),
    height = 1,
    focusable = false,
    style = "minimal",
    border = "none",
    zindex = 5,
    noautocmd = true,
  }
  if corner.win and vim.api.nvim_win_is_valid(corner.win) then
    vim.api.nvim_win_set_config(corner.win, cfg)
  else
    corner.win = vim.api.nvim_open_win(corner.buf, false, cfg)
  end
  vim.wo[corner.win].winhighlight = "Normal:SnacksDashboardNormal,NormalFloat:SnacksDashboardNormal"
end

local function corner_setup()
  local group = vim.api.nvim_create_augroup("dashboard_corner", { clear = true })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = { "SnacksDashboardOpened", "SnacksDashboardUpdatePost" },
    callback = function()
      vim.schedule(corner_update)
    end,
  })
  vim.api.nvim_create_autocmd("User", { group = group, pattern = "SnacksDashboardClosed", callback = corner_close })
  -- Le buffer dashboard quitte sa fenêtre sans être supprimé (:edit, autre buffer) ou la fenêtre est fermée.
  vim.api.nvim_create_autocmd({ "BufWinLeave", "WinClosed" }, {
    group = group,
    callback = function(ev)
      if ev.event == "WinClosed" or vim.bo[ev.buf].filetype == "snacks_dashboard" then
        vim.schedule(function()
          if not dashboard_win() then
            corner_close()
          end
        end)
      end
    end,
  })
end

return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    corner_setup()
    opts.dashboard = opts.dashboard or {}
    opts.dashboard.sections = {
      header_sections,
      { section = "keys", gap = 1, padding = 1 },
      { section = "startup" },
    }
  end,
}
