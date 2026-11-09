-- Helpers partages par les onglets agent (claude / opencode, vim.t.ai_tab)
local M = {}

-- Ouvre neo-tree a gauche dans l'onglet courant, puis redonne le focus a `term_win`
-- (insert mode). No-op silencieux si :Neotree n'existe pas.
M.show_tree = function(term_win)
  if vim.fn.exists(":Neotree") == 2 then
    pcall(vim.cmd, "Neotree show filesystem left")
  end
  if term_win and vim.api.nvim_win_is_valid(term_win) then
    vim.api.nvim_set_current_win(term_win)
  end
  vim.cmd("startinsert")
end

-- Fenetre de l'onglet `tab` qui affiche le buffer `buf` (nil si aucune).
M.win_showing = function(tab, buf)
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    if vim.api.nvim_win_get_buf(w) == buf then
      return w
    end
  end
end

local function is_float(w)
  return vim.api.nvim_win_get_config(w).relative ~= ""
end

local function is_tree(w)
  return vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "neo-tree"
end

-- Garantit que le terminal `buf` est affiche dans l'onglet agent `tab` (la marque
-- vim.t.ai_tab peut etre perimee : un fichier a pu remplacer le terminal). Sinon le
-- remet dans la fenetre principale (ni flottante ni neo-tree), ou dans un vsplit a
-- droite de neo-tree. Ne change pas le focus. Retourne la fenetre, ou nil.
M.ensure_terminal = function(tab, buf)
  if not (tab and vim.api.nvim_tabpage_is_valid(tab) and buf and vim.api.nvim_buf_is_valid(buf)) then
    return nil
  end
  local win = M.win_showing(tab, buf)
  if win then
    return win
  end
  local main, tree
  local cur = vim.api.nvim_tabpage_get_win(tab)
  local wins = vim.api.nvim_tabpage_list_wins(tab)
  table.insert(wins, 1, cur)
  for _, w in ipairs(wins) do
    if not is_float(w) then
      if is_tree(w) then
        tree = tree or w
      else
        main = w
        break
      end
    end
  end
  if main then
    if pcall(vim.api.nvim_win_set_buf, main, buf) then
      return main
    end
    return nil
  end
  if tree then
    local ok, w = pcall(vim.api.nvim_open_win, buf, false, { split = "right", win = tree })
    if ok then
      return w
    end
  end
  return nil
end

-- Dernier onglet agent : enleve la marque et remplace le terminal `term_buf` par un
-- buffer normal (le plus recent), sinon un buffer vide ; le terminal reste vivant.
-- Ne touche jamais une fenetre neo-tree ou flottante.
M.release_last_tab = function(tab, term_buf)
  pcall(vim.api.nvim_tabpage_del_var, tab, "ai_tab")
  local win = term_buf and M.win_showing(tab, term_buf)
  if not win or is_float(win) or is_tree(win) then
    return
  end
  local infos = vim.fn.getbufinfo({ buflisted = 1 })
  table.sort(infos, function(a, b) return a.lastused > b.lastused end)
  local alt
  for _, i in ipairs(infos) do
    if i.bufnr ~= term_buf and vim.api.nvim_buf_is_valid(i.bufnr) and vim.bo[i.bufnr].buftype == "" then
      alt = i.bufnr
      break
    end
  end
  if not alt then
    alt = vim.api.nvim_create_buf(true, false)
    vim.bo[alt].bufhidden = "wipe"
  end
  vim.api.nvim_win_set_buf(win, alt)
end

local function is_ai_tab(tab)
  local ok, v = pcall(vim.api.nvim_tabpage_get_var, tab, "ai_tab")
  return ok and v ~= nil
end

-- Ouvre `path` dans un onglet dedie (jamais de split) : saute vers l'onglet non-agent
-- qui l'affiche deja, sinon cree un onglet a la fin avec ce seul fichier.
M.open_in_code_tab = function(path)
  local full = vim.fn.fnamemodify(path, ":p")
  for _, t in ipairs(vim.api.nvim_list_tabpages()) do
    if not is_ai_tab(t) then
      for _, w in ipairs(vim.api.nvim_tabpage_list_wins(t)) do
        if vim.api.nvim_win_get_config(w).relative == ""
          and vim.fn.fnamemodify(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w)), ":p") == full then
          vim.api.nvim_set_current_tabpage(t)
          vim.api.nvim_set_current_win(w)
          return
        end
      end
    end
  end
  vim.cmd("$tabedit " .. vim.fn.fnameescape(full))
  local file_win = vim.api.nvim_get_current_win()
  if vim.fn.exists(":Neotree") == 2 then
    -- reveal seulement si le fichier est sous le cwd (sinon neo-tree ouvre une confirmation)
    local cmd = "Neotree show filesystem left"
    if vim.startswith(full, vim.fn.getcwd() .. "/") then
      cmd = cmd .. " reveal_file=" .. vim.fn.fnameescape(full)
    end
    pcall(vim.cmd, cmd)
  end
  if vim.api.nvim_win_is_valid(file_win) then
    vim.api.nvim_set_current_win(file_win)
  end
  vim.cmd("stopinsert")
end

return M
