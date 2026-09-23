-- WezTerm : portage de config/.config/kitty/kitty.conf (couleurs, splits, onglets).
-- Même fichier pour Linux et Windows (chargé par ~\.wezterm.lua, cf. script/get.ps1) ; les
-- différences sont regroupées derrière IS_WINDOWS.
local wezterm = require("wezterm")
local act = wezterm.action

local config = wezterm.config_builder()

local IS_WINDOWS = wezterm.target_triple:find("windows") ~= nil

-- --- Apparence ---------------------------------------------------------------
config.font = wezterm.font_with_fallback({ "MesloLGS NF", "Cascadia Mono", "Consolas" })
-- Windows : le portable est à 125 % d'échelle, 11 y paraît trop gros ; 8.25
-- = 10 réduit deux fois avec ctrl+- (÷1,1 à chaque fois), réglé à l'œil.
config.font_size = IS_WINDOWS and 8.25 or 11.0
-- Rendu plus proche de kitty : hinting léger (comme Xft.hintstyle=hintslight)
-- et antialiasing sous-pixel, qui donne un trait plus net et plus dense.
config.freetype_load_target = "Light"
config.freetype_render_target = "HorizontalLcd"
config.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }
config.check_for_updates = false

-- Rendu : OpenGL (défaut). WebGpu/Vulkan sur la RTX 3050 (pilote NVIDIA, X11)
-- faisait tourner l'interface à ~95 % de CPU en continu : raccourcis et clics
-- d'onglet ignorés. Ne pas le réactiver sans revérifier ce point.

-- --- Pas de sessions persistantes ------------------------------------------------
-- Testé puis retiré : en mode connecté à wezterm-mux-server (unix domain), avec
-- une dizaine d'onglets LazyVim splittés, le client perd la taille finale d'un
-- redimensionnement (contenu bloqué à une taille intermédiaire). Même défaut
-- avec la nightly ; le mode local suit à chaque fois. Les workspaces restent.
-- Fermer une fenêtre tue ses onglets : WezTerm demande confirmation si un
-- programme autre qu'un shell (nvim, Claude...) tourne.

-- --- Windows : shell par défaut ------------------------------------------------
-- zsh, oh-my-zsh, nvim et les sessions (de-session...) vivent dans WSL : on
-- ouvre directement la distribution WSL (Ubuntu en priorité), sinon PowerShell.
if IS_WINDOWS then
  local wsl = wezterm.default_wsl_domains()
  local chosen
  for _, dom in ipairs(wsl) do
    if dom.name:find("Ubuntu") then
      chosen = dom
      break
    end
  end
  chosen = chosen or wsl[1]
  if chosen then
    chosen.default_cwd = "~"
    config.wsl_domains = wsl
    config.default_domain = chosen.name
  else
    config.default_prog = { "pwsh.exe", "-NoLogo" }
  end
end

-- --- Disposition clavier -------------------------------------------------------
-- Seules les lettres du saut entre splits (ctrl+alt+a / ctrl+alt+x) dépendent
-- de la disposition : on affiche une lettre par split, autant qu'elles tombent
-- sous les doigts. Le reste des raccourcis suit le caractère produit (« z »
-- reste « z » en AZERTY comme en BÉPO), donc rien d'autre à adapter.
-- Détection : ~/.config/wezterm/keyboard (bepo | azerty | qwerty) s'il existe,
-- sinon setxkbmap sous Linux, sinon AZERTY sous Windows.
local HOME_ROWS = {
  bepo = "auietsrn",
  azerty = "qsdfghjklm",
  qwerty = "asdfghjkl",
}

local function detect_keyboard()
  local override = io.open((os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config"))
    .. "/wezterm/keyboard", "r")
  if override then
    local want = (override:read("*l") or ""):gsub("%s", "")
    override:close()
    if HOME_ROWS[want] then
      return want
    end
  end
  if IS_WINDOWS then
    return "azerty" -- clavier du laptop ; fichier `keyboard` pour forcer autre chose
  end
  local ok, pipe = pcall(io.popen, "setxkbmap -query 2>/dev/null")
  if ok and pipe then
    local out = pipe:read("*a") or ""
    pipe:close()
    if out:find("bepo") then
      return "bepo"
    elseif out:find("layout:%s*fr") or out:find("azerty") or out:find("oss") then
      return "azerty"
    end
  end
  return "qwerty"
end

local KEYBOARD = detect_keyboard()
local PANE_KEYS = HOME_ROWS[KEYBOARD]

local BG = "#121212"
local ACTIVE_TAB_BG = "#00cc7a"
local INACTIVE_TAB_FG = "#f9f9f9"
local SOFT_FG = "#767676"
local BELL_FG = "#cecb00"

-- Workspaces ouverts, mémorisés pour la reprise au démarrage (wez-pick startup).
local STATE_DIR = (os.getenv("XDG_STATE_HOME")
  or ((os.getenv("HOME") or os.getenv("USERPROFILE") or ".") .. "/.local/state")) .. "/wezterm"
local WORKSPACES_FILE = STATE_DIR .. "/workspaces"
local last_remembered = ""

-- Écrit la liste des workspaces « de travail » (hors home) quand elle change.
local function remember_workspaces()
  -- Sert à la reprise au démarrage (wez-pick, Linux/WSL). Sous Windows, le
  -- sélecteur natif prend le relais : rien à écrire, et pas de `mkdir -p`.
  if IS_WINDOWS then
    return
  end
  local names = {}
  for _, name in ipairs(wezterm.mux.get_workspace_names()) do
    if name ~= "home" then
      table.insert(names, name)
    end
  end
  table.sort(names)
  local joined = table.concat(names, "\n")
  if joined == last_remembered then
    return
  end
  last_remembered = joined
  os.execute('mkdir -p "' .. STATE_DIR .. '"')
  local f = io.open(WORKSPACES_FILE, "w")
  if f then
    f:write(joined .. (joined == "" and "" or "\n"))
    f:close()
  end
end

-- Workspaces ouverts, triés : ordre commun à la barre, alt+1…9 et wez-pick.
-- Workspace de départ (au lieu de « default », qui ne veut rien dire).
config.default_workspace = "home"

local WS_BUTTON = " " .. wezterm.nerdfonts.cod_window .. " workspaces ▾ "
config.tab_bar_style = {
  new_tab = wezterm.format({
    { Attribute = { Italic = false } },
    { Background = { Color = "#1e2a24" } },
    { Foreground = { Color = ACTIVE_TAB_BG } },
    { Text = WS_BUTTON },
  }),
  new_tab_hover = wezterm.format({
    { Attribute = { Italic = false } },
    { Background = { Color = ACTIVE_TAB_BG } },
    { Foreground = { Color = BG } },
    { Text = WS_BUTTON },
  }),
}

local function sorted_workspaces()
  local names = wezterm.mux.get_workspace_names()
  table.sort(names)
  return names
end

-- Palette par défaut de kitty (kitty.conf ne surcharge que le fond).
config.colors = {
  foreground = "#dddddd",
  background = BG,
  cursor_bg = "#cccccc",
  cursor_fg = "#111111",
  cursor_border = "#cccccc",
  selection_fg = "#000000",
  selection_bg = "#fffacd",
  split = "#444444",
  ansi = { "#000000", "#cc0403", "#19cb00", "#cecb00", "#0d73cc", "#cb1ed1", "#0dcdcd", "#dddddd" },
  brights = { "#767676", "#f2201f", "#23fd00", "#fffd00", "#1a8fff", "#fd28ff", "#14ffff", "#ffffff" },
  tab_bar = {
    background = BG,
    active_tab = { bg_color = ACTIVE_TAB_BG, fg_color = BG },
    inactive_tab = { bg_color = BG, fg_color = INACTIVE_TAB_FG },
    inactive_tab_hover = { bg_color = "#2a2a2a", fg_color = INACTIVE_TAB_FG },
  },
}

-- Split inactif légèrement assombri : on voit tout de suite où est le focus.
config.inactive_pane_hsb = { saturation = 0.9, brightness = 0.7 }

-- --- Barre d'onglets (en bas, comme kitty) -----------------------------------
-- Barre "retro" : même hauteur que dans kitty (une ligne du terminal), pas de
-- bouton de fermeture.
config.use_fancy_tab_bar = false
-- Le bouton « nouvel onglet » devient un bouton « workspaces ▾ » : c'est le
-- seul élément cliquable de la barre en plus des onglets (la zone de statut à
-- droite ne reçoit pas les clics). Clic gauche : sélecteur de workspaces ;
-- clic droit : recherche d'onglet. Voir l'événement new-tab-button-click.
config.show_new_tab_button_in_tab_bar = true
config.tab_bar_at_bottom = true
-- Barre toujours visible : elle affiche le workspace courant, et la faire
-- apparaître au 2e onglet redimensionne la fenêtre pendant que les sessions
-- zsh créent leurs splits (split 70/30 faussé sur le premier onglet).
config.hide_tab_bar_if_only_one_tab = false
config.tab_max_width = 40

-- Pas de callback format-tab-title : WezTerm le rappelle pour chaque onglet à
-- chaque mouvement de souris sur la barre, en reconvertissant toute la config
-- en Lua. Avec une dizaine d'onglets, un clic mettait 2-3 s à s'afficher
-- (0,1 s sans). La barre native affiche "1: titre" avec les couleurs ci-dessus.

-- Bell (fin de Claude Code, `printf '\a'`...) : notification système si la
-- fenêtre n'a pas le focus, et marquage du workspace concerné (barre du bas en
-- jaune + cloche dans le sélecteur), effacé dès qu'on le regarde.
local bells = {}

wezterm.on("bell", function(window, pane)
  -- Le workspace qui a sonné, pas celui affiché : la cloche arrive aussi des
  -- workspaces cachés (Claude Code qui attend dans une autre session).
  local ok, ws = pcall(function()
    return pane:tab():window():get_workspace()
  end)
  if not ok or not ws then
    ws = window:active_workspace()
  end
  local focused = window:is_focused()
  local active = window:active_pane()
  if focused and ws == window:active_workspace() and active and active:pane_id() == pane:pane_id() then
    return -- on regarde déjà ce pane
  end
  bells[ws] = true
  if not focused then
    local tab = pane:tab()
    local title = tab and tab:get_title() or ""
    if title == "" then
      title = pane:get_title()
    end
    window:toast_notification("WezTerm", "Terminé / en attente : " .. title, nil, 5000)
  end
end)

-- Titre de la fenêtre : "[n/N] dossier-parent/dossier", précédé du programme
-- s'il ne s'agit pas d'un shell ("[4/11] nvim · data-engineering-wt/de-MAR-…").
-- pane.title renvoie le titre court d'oh-my-zsh (OSC 1), d'où la reconstruction.
local SHELLS = {
  zsh = true, bash = true, sh = true, fish = true,
  -- Windows : shell natif, ou WSL vu depuis Windows (wsl.exe / wslhost.exe).
  pwsh = true, powershell = true, cmd = true, wsl = true, wslhost = true,
}
local HOME = (os.getenv("HOME") or os.getenv("USERPROFILE") or ""):gsub("\\", "/")

local function short_cwd(pane)
  local cwd = pane.current_working_dir
  local path = cwd and (cwd.file_path or tostring(cwd):gsub("^file://[^/]*", "")) or nil
  if not path then
    return nil
  end
  path = path:gsub("/$", "")
  if path == HOME or path == "" then
    return "~"
  end
  local parent, dir = path:match("([^/]+)/([^/]+)$")
  if parent then
    return parent .. "/" .. dir
  end
  return path
end

-- foreground_process_name / current_working_dir interrogent /proc à chaque
-- accès, et ce callback est rappelé à chaque rendu (y compris à chaque
-- mouvement de souris sur la barre d'onglets) : sans cache, les appels
-- s'empilent et un clic d'onglet met plusieurs secondes à s'afficher.
-- On ne recalcule donc la partie "programme · dossier" qu'une fois par seconde
-- et par pane.
local title_cache = {}

wezterm.on("format-window-title", function(tab, pane, tabs)
  local prefix = ""
  if #tabs > 1 then
    prefix = "[" .. (tab.tab_index + 1) .. "/" .. #tabs .. "] "
  end
  local now = os.time()
  local cached = title_cache[pane.pane_id]
  if not cached or cached.at ~= now then
    local proc = (pane.foreground_process_name or ""):match("([^/\\]+)$") or ""
    proc = proc:gsub("%.exe$", "")
    local dir = short_cwd(pane) or pane.title
    local body = dir
    if proc ~= "" and not SHELLS[proc] then
      body = proc .. " · " .. dir
    end
    cached = { at = now, body = body }
    title_cache[pane.pane_id] = cached
  end
  return prefix .. cached.body
end)

-- --- ctrl+b : revenir au pane précédemment actif (nth_window -1 de kitty) ----
-- On mémorise, par onglet, le pane courant et le précédent.
local pane_history = {}

local function track_pane(pane)
  local tab = pane:tab()
  if not tab then
    return nil
  end
  local tab_id = tab:tab_id()
  local state = pane_history[tab_id] or {}
  if state.cur ~= pane:pane_id() then
    state.prev = state.cur
    state.cur = pane:pane_id()
  end
  pane_history[tab_id] = state
  return tab, state
end

-- Filet de sécurité pour les changements de focus à la souris (intervalle par
-- défaut : un polling plus fréquent ralentit l'UI, notamment les clics d'onglet).
wezterm.on("update-status", function(window, pane)
  track_pane(pane)

  local cells = {}
  local mode = window:active_key_table()
  if mode then
    table.insert(cells, { Background = { Color = "#cecb00" } })
    table.insert(cells, { Foreground = { Color = BG } })
    table.insert(cells, { Text = " " .. mode:upper() .. " " })
  end
  -- Barre des workspaces : « 1 de  2 ms  3 marvin », l'actuel en vert (jaune
  -- s'il attend). Mêmes numéros que alt+1…9 et que le sélecteur.
  local current = window:active_workspace()
  if window:is_focused() then
    bells[current] = nil
  end
  remember_workspaces()
  table.insert(cells, { Background = { Color = BG } })
  table.insert(cells, { Foreground = { Color = SOFT_FG } })
  table.insert(cells, { Text = " " .. wezterm.nerdfonts.cod_window .. " " })
  for i, name in ipairs(sorted_workspaces()) do
    if name == current then
      table.insert(cells, { Background = { Color = bells[name] and BELL_FG or ACTIVE_TAB_BG } })
      table.insert(cells, { Foreground = { Color = BG } })
    elseif bells[name] then
      table.insert(cells, { Background = { Color = BG } })
      table.insert(cells, { Foreground = { Color = BELL_FG } })
    else
      table.insert(cells, { Background = { Color = BG } })
      table.insert(cells, { Foreground = { Color = INACTIVE_TAB_FG } })
    end
    table.insert(cells, { Text = " " .. i .. " " .. name .. " " })
  end
  window:set_right_status(wezterm.format(cells))
end)

-- Les fonctions de session zsh (de-session...) demandent la bascule vers leur
-- workspace via une user var : printf '\e]1337;SetUserVar=switch_workspace=<base64>\a'.
wezterm.on("user-var-changed", function(window, pane, name, value)
  if name == "switch_workspace" and value ~= "" then
    window:perform_action(act.SwitchToWorkspace({ name = value }), pane)
  end
end)

-- Navigation clavier : on enregistre le pane quitté avant de bouger.
local function move_to(direction)
  return wezterm.action_callback(function(window, pane)
    track_pane(pane)
    window:perform_action(act.ActivatePaneDirection(direction), pane)
    local tab = pane:tab()
    local active = tab and tab:active_pane()
    if active then
      track_pane(active)
    end
  end)
end

local goto_previous_pane = wezterm.action_callback(function(_, pane)
  local tab, state = track_pane(pane)
  if not tab or not state.prev then
    return
  end
  for _, p in ipairs(tab:panes()) do
    if p:pane_id() == state.prev then
      p:activate()
      state.prev, state.cur = state.cur, state.prev
      return
    end
  end
end)

-- --- Liens et Quick Select ---------------------------------------------------
-- TERM=wezterm : active le soulignement ondulé/coloré (diagnostics LSP de nvim).
-- Nécessite le terminfo `wezterm` (script/install le compile dans ~/.terminfo) ;
-- .zshrc repasse en xterm-256color pour ssh. Pas sous Windows : WSL n'a pas ce
-- terminfo et garde le TERM par défaut.
if not IS_WINDOWS then
  config.term = "wezterm"
end

-- Tickets Linear cliquables partout (git log, logs, Claude...) : MAR-1234.
local LINEAR_ISSUE_URL = "https://linear.app/marvin-recruiter/issue/"
config.hyperlink_rules = wezterm.default_hyperlink_rules()
table.insert(config.hyperlink_rules, {
  regex = [[\b(MAR-\d+)\b]],
  format = LINEAR_ISSUE_URL .. "$1",
})

-- Quick Select (ctrl+shift+espace) : repère aussi les tickets en plus des SHA,
-- chemins, URLs, IP... déjà gérés par WezTerm.
config.quick_select_patterns = { [[\bMAR-\d+\b]] }

-- ctrl+alt+o : lettres sur les tickets visibles, la lettre ouvre le ticket
-- (ctrl+alt+l est pris par Cinnamon pour verrouiller l'écran).
local open_linear_ticket = act.QuickSelectArgs({
  label = "ouvrir le ticket Linear",
  patterns = { [[\bMAR-\d+\b]] },
  action = wezterm.action_callback(function(window, pane)
    local ticket = window:get_selection_text_for_pane(pane)
    if ticket ~= "" then
      wezterm.open_with(LINEAR_ISSUE_URL .. ticket)
    end
  end),
})

-- --- Aide, renommage, workspaces nommés ----------------------------------------
-- F1 : aide-mémoire (cheatsheet.txt, à côté de ce fichier) dans un split à
-- droite, fermé avec q. Même contenu que `wez-help` dans zsh.
-- Sous Windows, le pane tourne dans WSL : on y lit la copie WSL du dotfiles
-- (le chemin Windows de wezterm.config_dir n'y est pas lisible).
local show_cheatsheet = act.SplitPane({
  direction = "Right",
  size = { Percent = 45 },
  command = {
    args = IS_WINDOWS
        and { "bash", "-lc", "less -R -~ ~/.config/wezterm/cheatsheet.txt" }
      or { "less", "-R", "-~", wezterm.config_dir .. "/cheatsheet.txt" },
  },
})

local rename_tab = act.PromptInputLine({
  description = "Nom de l'onglet (vide = annuler)",
  action = wezterm.action_callback(function(window, _, line)
    if line and line ~= "" then
      window:active_tab():set_title(line .. " ")
    end
  end),
})

local goto_named_workspace = act.PromptInputLine({
  description = "Workspace à créer ou rejoindre (vide = annuler)",
  action = wezterm.action_callback(function(window, pane, line)
    if line and line ~= "" then
      window:perform_action(act.SwitchToWorkspace({ name = line }), pane)
    end
  end),
})

-- --- Sélecteurs de workspaces et d'onglets ------------------------------------
-- Construits à la demande (pas à chaque rendu : aucun coût sur les clics).
-- Le lanceur natif cherche dans « Switch to workspace: `nom` » (taper « s » ou
-- « w » correspond à tout) et masque le workspace courant ; ici on ne cherche
-- que dans les noms, et les onglets sont cherchés dans tous les workspaces.
local function tab_label(tab)
  local title = tab:get_title():gsub("%s+$", "")
  if title == "" then
    local pane = tab:active_pane()
    title = pane and pane:get_title() or "?"
  end
  return title
end

local choose_workspace = wezterm.action_callback(function(window, pane)
  local current = window:active_workspace()
  local counts = {}
  for _, mux_win in ipairs(wezterm.mux.all_windows()) do
    local ws = mux_win:get_workspace()
    counts[ws] = (counts[ws] or 0) + #mux_win:tabs()
  end
  local names = {}
  for name in pairs(counts) do
    table.insert(names, name)
  end
  table.sort(names)
  local choices = {}
  for _, name in ipairs(names) do
    local mark = name == current and "● " or "  "
    table.insert(choices, {
      id = name,
      label = mark .. name .. "   (" .. counts[name] .. " onglet" .. (counts[name] > 1 and "s" or "") .. ")",
    })
  end
  window:perform_action(
    act.InputSelector({
      title = "Workspaces",
      description = "Taper un bout de nom, Entrée pour y aller (● = actuel, ctrl+alt+n pour en créer un)",
      fuzzy_description = "Workspace : ",
      fuzzy = true,
      choices = choices,
      action = wezterm.action_callback(function(win, p, id)
        if id then
          win:perform_action(act.SwitchToWorkspace({ name = id }), p)
        end
      end),
    }),
    pane
  )
end)

local choose_tab = wezterm.action_callback(function(window, pane)
  local current = window:active_workspace()
  local choices = {}
  local targets = {}
  for _, mux_win in ipairs(wezterm.mux.all_windows()) do
    local ws = mux_win:get_workspace()
    for i, tab in ipairs(mux_win:tabs()) do
      local id = tostring(tab:tab_id())
      targets[id] = { ws = ws, tab = tab }
      table.insert(choices, {
        id = id,
        label = (ws == current and "● " or "  ") .. ws .. " › " .. i .. ": " .. tab_label(tab),
      })
    end
  end
  window:perform_action(
    act.InputSelector({
      title = "Onglets",
      description = "Taper un bout de nom (tous workspaces), Entrée pour y aller",
      fuzzy_description = "Onglet : ",
      fuzzy = true,
      choices = choices,
      action = wezterm.action_callback(function(win, p, id)
        local target = id and targets[id]
        if not target then
          return
        end
        if target.ws ~= win:active_workspace() then
          win:perform_action(act.SwitchToWorkspace({ name = target.ws }), p)
        end
        target.tab:activate()
      end),
    }),
    pane
  )
end)

-- Sélecteur plein écran façon Telescope (bin/.local/bin/wez-pick, fzf) : liste
-- à gauche, aperçu réel de l'écran à droite, sessions pas encore ouvertes
-- lançables. Ouvert dans un pane zoomé qui se ferme à la sortie. On lui passe
-- l'état (onglet actif de chaque workspace) que `wezterm cli list` n'expose pas.
local WEZ_PICK = (os.getenv("HOME") or "") .. "/.local/bin/wez-pick"

-- Pane du sélecteur ouvert, par fenêtre : un double clic ou un raccourci
-- répété ne doit pas en empiler un second.
local open_pickers = {}

local function picker_is_open(window)
  local id = open_pickers[window:window_id()]
  if not id then
    return false
  end
  for _, tab in ipairs(window:mux_window():tabs()) do
    for _, p in ipairs(tab:panes()) do
      if p:pane_id() == id then
        return true
      end
    end
  end
  open_pickers[window:window_id()] = nil
  return false
end

local function open_picker(mode)
  return wezterm.action_callback(function(window, pane)
    if picker_is_open(window) then
      return
    end
    local pending = {}
    for ws in pairs(bells) do
      table.insert(pending, ws)
    end
    local state = { current = window:active_workspace(), bells = pending, windows = {} }
    for _, mux_win in ipairs(wezterm.mux.all_windows()) do
      local tabs = {}
      for _, info in ipairs(mux_win:tabs_with_info()) do
        local active = info.tab:active_pane()
        table.insert(tabs, {
          tab_id = info.tab:tab_id(),
          index = info.index + 1,
          title = tab_label(info.tab),
          is_active = info.is_active,
          pane_id = active and active:pane_id() or nil,
        })
      end
      table.insert(state.windows, { workspace = mux_win:get_workspace(), tabs = tabs })
    end
    local path = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/wez-pick-" .. window:window_id() .. ".json"
    local f = io.open(path, "w")
    if not f then
      return
    end
    f:write(wezterm.json_encode(state))
    f:close()
    local picker = pane:split({ direction = "Bottom", size = 0.5, args = { WEZ_PICK, mode, path } })
    open_pickers[window:window_id()] = picker:pane_id()
    picker:activate()
    window:perform_action(act.SetPaneZoomState(true), picker)
  end)
end

local pick_workspace = IS_WINDOWS and choose_workspace or open_picker("workspaces")
local pick_tab = IS_WINDOWS and choose_tab or open_picker("tabs")

wezterm.on("new-tab-button-click", function(window, pane, button)
  if button == "Left" then
    window:perform_action(pick_workspace, pane)
  elseif button == "Right" then
    window:perform_action(pick_tab, pane)
  end
  return false
end)

-- Au démarrage : le shell de « home » propose de reprendre les workspaces de la
-- dernière fois (wez-pick startup). Sans historique, il ouvre un shell normal.
if not IS_WINDOWS then
  wezterm.on("gui-startup", function(cmd)
    -- `wezterm start -- prog` : on respecte le programme demandé.
    if cmd and cmd.args then
      wezterm.mux.spawn_window(cmd)
      return
    end
    -- Sinon (menu, `wezterm`, `wezterm start --cwd .`) : shell qui propose
    -- d'abord de reprendre les workspaces de la dernière fois.
    local shell = os.getenv("SHELL") or "/usr/bin/zsh"
    wezterm.mux.spawn_window({
      cwd = cmd and cmd.cwd or nil,
      args = { shell, "-ic", WEZ_PICK .. " startup; exec " .. shell .. " -i" },
    })
  end)
end

-- alt+1…9 : workspace n (touches physiques du haut du clavier, sans Shift en BÉPO).
local function goto_workspace(n)
  return wezterm.action_callback(function(window, pane)
    local name = sorted_workspaces()[n]
    if name and name ~= window:active_workspace() then
      window:perform_action(act.SwitchToWorkspace({ name = name }), pane)
    end
  end)
end

-- --- Raccourcis ---------------------------------------------------------------
-- Sous Windows, AltGr arrive comme ctrl+alt : ctrl+alt+lettre avalerait les
-- caractères AltGr du BÉPO ( } = AltGr+x, œ = AltGr+o, æ = AltGr+a...). On y
-- ajoute donc Shift pour les raccourcis à lettre ; les flèches ne changent pas.
local CA = IS_WINDOWS and "CTRL|ALT|SHIFT" or "CTRL|ALT"

config.keys = {
  { key = "b", mods = "CTRL", action = goto_previous_pane },

  -- Shift-Enter distinct de Enter (CSI-u) pour nvim / Claude Code.
  { key = "Enter", mods = "SHIFT", action = act.SendString("\x1b[13;2u") },

  -- Splits dans le dossier courant.
  { key = "RightArrow", mods = "CTRL|ALT|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { key = "DownArrow", mods = "CTRL|ALT|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },

  -- Focus du split voisin.
  { key = "LeftArrow", mods = "CTRL|ALT", action = move_to("Left") },
  { key = "RightArrow", mods = "CTRL|ALT", action = move_to("Right") },
  { key = "UpArrow", mods = "CTRL|ALT", action = move_to("Up") },
  { key = "DownArrow", mods = "CTRL|ALT", action = move_to("Down") },

  -- Mode redimensionnement (flèches, puis Échap / Entrée pour sortir).
  { key = "r", mods = CA, action = act.ActivateKeyTable({ name = "resize", one_shot = false }) },

  -- Onglets (raccourcis par défaut de kitty + ceux de kitty.conf).
  -- ctrl+shift+←/→ déplacent le focus entre splits par défaut dans WezTerm :
  -- on les remappe sur les onglets comme dans kitty.
  { key = "RightArrow", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(1) },
  { key = "LeftArrow", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(-1) },
  -- Déplacer l'onglet : ctrl+shift+PageUp/PageDown (défaut WezTerm ; en BÉPO,
  -- < et > sont sur AltGr, donc pas de ctrl+shift+< / > comme dans kitty).
  { key = "q", mods = "CTRL|SHIFT", action = act.CloseCurrentTab({ confirm = false }) },
  { key = "Tab", mods = "CTRL", action = act.ActivateTabRelative(1) },
  { key = "Tab", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(-1) },
  -- Nouvel onglet : ctrl+shift+t (défaut WezTerm) ; ctrl+alt+t est pris par
  -- Cinnamon (ouvrir un terminal).
  { key = "w", mods = CA, action = act.CloseCurrentTab({ confirm = false }) },

  -- Aide-mémoire.
  { key = "F1", action = show_cheatsheet },

  -- Renommer l'onglet.
  { key = "e", mods = CA, action = rename_tab },

  -- Workspaces (un par session : de-session, ms-session...).
  { key = "s", mods = "CTRL|SHIFT", action = pick_workspace },
  { key = "PageDown", mods = "CTRL|ALT", action = act.SwitchWorkspaceRelative(1) },
  { key = "PageUp", mods = "CTRL|ALT", action = act.SwitchWorkspaceRelative(-1) },
  { key = "n", mods = CA, action = goto_named_workspace },

  -- Recherche floue d'onglet, et sélection / échange de split par lettre
  -- (rangée de repos de la disposition détectée).
  -- Chercher un onglet dans tous les workspaces.
  { key = "o", mods = "CTRL|SHIFT", action = pick_tab },

  -- Une seule fenêtre : pas de nouvelle fenêtre au clavier (tout passe par les
  -- workspaces).
  { key = "n", mods = "CTRL|SHIFT", action = act.DisableDefaultAssignment },
  { key = "a", mods = CA, action = act.PaneSelect({ alphabet = PANE_KEYS }) },
  { key = "x", mods = CA, action = act.PaneSelect({ alphabet = PANE_KEYS, mode = "SwapWithActive" }) },

  -- Ouvrir un ticket Linear visible à l'écran (MAR-xxxx) sans la souris.
  { key = "o", mods = CA, action = open_linear_ticket },

  -- Zoom du split actif (toggle_layout stack).
  { key = "z", mods = CA, action = act.TogglePaneZoomState },
}

for i = 1, 9 do
  table.insert(config.keys, { key = "phys:" .. i, mods = "ALT", action = goto_workspace(i) })
end

config.key_tables = {
  resize = {
    { key = "LeftArrow", action = act.AdjustPaneSize({ "Left", 2 }) },
    { key = "RightArrow", action = act.AdjustPaneSize({ "Right", 2 }) },
    { key = "UpArrow", action = act.AdjustPaneSize({ "Up", 1 }) },
    { key = "DownArrow", action = act.AdjustPaneSize({ "Down", 1 }) },
    { key = "Escape", action = "PopKeyTable" },
    { key = "Enter", action = "PopKeyTable" },
  },
}

-- --- Souris -------------------------------------------------------------------
config.mouse_bindings = {
  -- copy_on_select : la sélection part aussi dans le presse-papiers. Un clic
  -- simple n'ouvre pas les liens : les MAR-xxxx sont partout (prompt, noms de
  -- worktree) et un clic pour donner le focus ouvrirait Linear.
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "NONE",
    action = act.CompleteSelection("ClipboardAndPrimarySelection"),
  },
  -- ctrl+clic : ouvrir le lien (URL, ticket Linear). Le Down est absorbé pour
  -- ne pas être transmis à nvim / au shell.
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "CTRL",
    action = act.OpenLinkAtMouseCursor,
  },
  {
    event = { Down = { streak = 1, button = "Left" } },
    mods = "CTRL",
    action = act.Nop,
  },
  -- ctrl+alt+glisser : sélection rectangulaire.
  {
    event = { Down = { streak = 1, button = "Left" } },
    mods = "CTRL|ALT",
    action = act.SelectTextAtMouseCursor("Block"),
  },
  {
    event = { Drag = { streak = 1, button = "Left" } },
    mods = "CTRL|ALT",
    action = act.ExtendSelectionToMouseCursor("Block"),
  },
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "CTRL|ALT",
    action = act.CompleteSelection("ClipboardAndPrimarySelection"),
  },
}

return config
