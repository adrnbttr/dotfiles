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

-- Fenetre ou creer un terminal dans l'onglet agent `tab` : la fenetre principale (ni
-- flottante ni neo-tree), sinon un vsplit a droite de neo-tree. Ne change pas le focus.
M.main_win = function(tab)
  if not (tab and vim.api.nvim_tabpage_is_valid(tab)) then
    return nil
  end
  local tree
  local wins = vim.api.nvim_tabpage_list_wins(tab)
  table.insert(wins, 1, vim.api.nvim_tabpage_get_win(tab))
  for _, w in ipairs(wins) do
    if not is_float(w) then
      if is_tree(w) then
        tree = tree or w
      else
        return w
      end
    end
  end
  if tree then
    local tmp = vim.api.nvim_create_buf(false, true)
    vim.bo[tmp].bufhidden = "wipe"
    local ok, w = pcall(vim.api.nvim_open_win, tmp, false, { split = "right", win = tree })
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

local function tree_win_of(tab, except)
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    if w ~= except and not is_float(w) and is_tree(w) then
      return w
    end
  end
end

-- Buffer a mettre a cote de neo-tree quand l'onglet agent perd son terminal : le buffer
-- de code le plus recent, sinon un buffer vide.
local function pick_code_buf(except)
  local infos = vim.fn.getbufinfo({ buflisted = 1 })
  table.sort(infos, function(a, b) return a.lastused > b.lastused end)
  for _, i in ipairs(infos) do
    if i.bufnr ~= except and vim.api.nvim_buf_is_valid(i.bufnr) and vim.bo[i.bufnr].buftype == "" then
      return i.bufnr
    end
  end
  local b = vim.api.nvim_create_buf(true, false)
  vim.bo[b].bufhidden = "wipe"
  return b
end

-- ---------------------------------------------------------------------------
-- Garde-fous
-- ---------------------------------------------------------------------------

local group = vim.api.nvim_create_augroup("AiTabGuard", { clear = true })
local LABELS = { claude = "Claude", opencode = "opencode" }

-- Getters du buffer terminal de chaque agent (nil si aucun) : le TermClose ne reagit qu'a
-- CE buffer, pas a un autre terminal affiche dans l'onglet agent.
local term_getters = {}
M.register_term = function(name, fn)
  term_getters[name] = fn
end
M.register_term("claude", function()
  return require("config.claude").term_buf()
end)

-- Remplace `buf` par un buffer de code dans les fenetres des onglets agent qui
-- l'affichent (avant de le supprimer : sinon la fermeture de la fenetre ferme l'onglet).
M.detach = function(buf)
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    if is_ai_tab(tab) then
      local win = M.win_showing(tab, buf)
      if win and not is_float(win) then
        pcall(vim.api.nvim_win_set_buf, win, pick_code_buf(buf))
      end
    end
  end
end

-- Vrai pendant la sortie de nvim : les terminaux meurent, ce n'est pas un evenement agent.
local exiting = false
vim.api.nvim_create_autocmd({ "ExitPre", "VimLeavePre" }, {
  group = group,
  callback = function()
    exiting = true
  end,
})

-- Neo-tree quitte nvim (`q!`) quand sa fenetre reste seule (close_if_last_window). Si la
-- fenetre du terminal de l'UNIQUE onglet, marque agent, se ferme, on neutralise ce quit
-- (le temps de l'evenement) puis on remplace le terminal par un buffer de code / vide.
-- Le terminal reste vivant. Doit etre declare APRES l'autocmd de neo-tree (voir
-- plugins/neo-tree.lua : appele depuis son `opts`) pour s'executer avant lui.
local guard_installed = false
local function try_install_guard()
  if guard_installed then
    return true
  end
  -- Groupe absent (opts evalue avant plugin/neo-tree.lua) : on reessaiera plus tard.
  local ok, nt_acs = pcall(vim.api.nvim_get_autocmds, { event = "WinClosed", group = "NeoTree" })
  if not ok then
    return false
  end
  guard_installed = true
  -- L'autocmd de neo-tree existe deja et passerait avant le notre : on le retire pour le
  -- recreer apres (meme callback, meme groupe).
  local found = {}
  for _, a in ipairs(nt_acs) do
    if a.callback and a.desc == "close_if_last_window autocmd" then
      table.insert(found, a)
      pcall(vim.api.nvim_del_autocmd, a.id)
    end
  end
  if #found == 0 then
    vim.notify(
      "ai_tab: autocmd WinClosed de neo-tree introuvable (desc changé ?) : garde-fou « dernier onglet agent » inefficace",
      vim.log.levels.WARN
    )
  end
  local function restore_neotree()
    for _, a in ipairs(found) do
      vim.api.nvim_create_autocmd("WinClosed", { group = "NeoTree", desc = a.desc, callback = a.callback })
    end
  end
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    desc = "onglet agent: ne pas quitter nvim quand le terminal se ferme",
    callback = function(args)
      local closing = tonumber(args.match)
      if not (closing and vim.api.nvim_win_is_valid(closing)) then
        return
      end
      local tab = vim.api.nvim_win_get_tabpage(closing)
      if #vim.api.nvim_list_tabpages() ~= 1 or not is_ai_tab(tab) then
        return
      end
      local others = {}
      for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
        if w ~= closing and not is_float(w) then
          table.insert(others, w)
        end
      end
      if #others ~= 1 or not is_tree(others[1]) then
        return
      end
      local tree = others[1]
      local ok, nt = pcall(function() return require("neo-tree").ensure_config() end)
      local prev
      if ok and type(nt) == "table" then
        prev = nt.close_if_last_window
        nt.close_if_last_window = false
      end
      vim.schedule(function()
        if ok and type(nt) == "table" then
          nt.close_if_last_window = prev
        end
        if not (vim.api.nvim_tabpage_is_valid(tab) and vim.api.nvim_win_is_valid(tree)) then
          return
        end
        pcall(vim.api.nvim_tabpage_del_var, tab, "ai_tab")
        if #vim.api.nvim_tabpage_list_wins(tab) == 1 then
          pcall(vim.api.nvim_open_win, pick_code_buf(), true, { split = "right", win = tree })
        end
      end)
    end,
  })
  restore_neotree()
  return true
end

M.install_guard = function()
  if try_install_guard() then
    return
  end
  local function retry()
    return try_install_guard() -- true => l'autocmd se supprime
  end
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = { "LazyLoad", "VeryLazy" },
    desc = "onglet agent: installer le garde-fou quand neo-tree est charge",
    callback = retry,
  })
  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    desc = "onglet agent: installer le garde-fou quand neo-tree est charge",
    callback = retry,
  })
end

-- Le process de l'agent se termine alors que son terminal est affiche dans l'onglet
-- agent : notification, fermeture de l'onglet, suppression du buffer mort (le prochain
-- zT/jT relance une session neuve). Le split garde son comportement (rien ici).
vim.api.nvim_create_autocmd("TermClose", {
  group = group,
  desc = "onglet agent: l'agent s'est arrete",
  callback = function(args)
    if exiting or vim.v.exiting ~= vim.NIL then
      return
    end
    local buf = args.buf
    local status = type(vim.v.event) == "table" and vim.v.event.status or 0
    if status == -1 then -- buffer supprime : pas une fin d'agent
      return
    end
    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
      local ok, name = pcall(vim.api.nvim_tabpage_get_var, tab, "ai_tab")
      local getter = ok and term_getters[name]
      if getter and getter() == buf and M.win_showing(tab, buf) then
        vim.notify(("%s terminé (code %s)"):format(LABELS[name], tostring(status)), vim.log.levels.INFO)
        vim.schedule(function()
          if vim.api.nvim_tabpage_is_valid(tab) then
            if #vim.api.nvim_list_tabpages() > 1 then
              pcall(vim.cmd, "tabclose " .. vim.api.nvim_tabpage_get_number(tab))
            else
              M.release_last_tab(tab, buf)
            end
          end
          if vim.api.nvim_buf_is_valid(buf) then
            pcall(vim.api.nvim_buf_delete, buf, { force = true })
          end
        end)
        return
      end
    end
  end,
})

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

-- ---------------------------------------------------------------------------
-- Ouverture d'un onglet agent au demarrage (`nvim --agent <nom> [--last]`, voir la
-- fonction nvim() de zsh/.zshrc, qui passe par `-c "lua ...request_agent(...)"`).
-- ---------------------------------------------------------------------------

local openers = {} -- nom -> function({ last = bool })

-- Un plugin/module enregistre ici sa fonction d'ouverture d'onglet.
M.register = function(name, fn)
  openers[name] = fn
end

local function open_agent(name, opts)
  if name == "claude" then
    require("config.claude").toggle_tab(opts)
    return
  end
  if name == "opencode" then
    -- le plugin enregistre son opener dans sa config : on la force si besoin
    if not openers.opencode then
      pcall(function() require("lazy").load({ plugins = { "opencode.nvim" } }) end)
    end
  end
  if openers[name] then
    openers[name](opts)
  else
    vim.notify("Agent inconnu ou indisponible : " .. tostring(name), vim.log.levels.ERROR)
  end
end

local pending

local function fire()
  if not pending then
    return
  end
  local req = pending
  pending = nil
  -- onglet de code (neo-tree compris) deja en place : on ouvre l'agent par-dessus
  open_agent(req.name, { last = req.last, prompt = req.prompt })
end

-- Demande l'ouverture de l'onglet agent une fois le demarrage termine : sur VeryLazy
-- (apres le neo-tree du premier onglet, cf. autocmds.lua), ou sur VimEnter en headless
-- (VeryLazy n'y est pas garanti). `pending` evite toute double ouverture.
-- `prompt_file` : fichier temporaire (cree par zsh) contenant le message initial ; lu puis
-- supprime tout de suite (le texte ne transite ni par un shell ni par l'environnement).
M.request_agent = function(name, last, prompt_file)
  local prompt
  if prompt_file and prompt_file ~= "" then
    local f = io.open(prompt_file, "rb")
    if f then
      prompt = f:read("*a")
      f:close()
    end
    os.remove(prompt_file)
  end
  pending = { name = name, last = last and true or false, prompt = prompt }
  local function later()
    vim.defer_fn(fire, 100)
  end
  vim.api.nvim_create_autocmd("User", { pattern = "VeryLazy", once = true, callback = later })
  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      if #vim.api.nvim_list_uis() == 0 then
        later()
      end
    end,
  })
end

return M
