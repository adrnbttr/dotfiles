-- WezTerm : portage de config/.config/kitty/kitty.conf (couleurs, splits, onglets).
-- Même fichier pour Linux et Windows (voir script/install-windows.ps1) ; les
-- différences sont regroupées derrière IS_WINDOWS.
local wezterm = require("wezterm")
local act = wezterm.action

local config = wezterm.config_builder()

local IS_WINDOWS = wezterm.target_triple:find("windows") ~= nil

-- --- Apparence ---------------------------------------------------------------
config.font = wezterm.font_with_fallback({ "MesloLGS NF", "Cascadia Mono", "Consolas" })
config.font_size = 11.0
-- Rendu plus proche de kitty : hinting léger (comme Xft.hintstyle=hintslight)
-- et antialiasing sous-pixel, qui donne un trait plus net et plus dense.
config.freetype_load_target = "Light"
config.freetype_render_target = "HorizontalLcd"
config.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }
config.check_for_updates = false

-- Rendu via WebGpu (Vulkan sous Linux, DirectX 12 sous Windows) sur le GPU
-- dédié s'il existe (RTX 3050 ici), sinon WezTerm choisit seul. Ne se
-- recharge pas à chaud : redémarrer l'interface pour l'appliquer.
config.front_end = "WebGpu"
config.webgpu_power_preference = "HighPerformance"
for _, gpu in ipairs(wezterm.gui and wezterm.gui.enumerate_gpus() or {}) do
  if gpu.backend ~= "Gl" and gpu.device_type == "DiscreteGpu" then
    config.webgpu_preferred_adapter = gpu
    break
  end
end

-- --- Sessions persistantes -----------------------------------------------------
-- Les shells, nvim et Claude Code tournent dans un serveur WezTerm en
-- arrière-plan (wezterm-mux-server, démarré automatiquement). Fermer la
-- fenêtre ou redémarrer l'interface ne tue rien : `wezterm` se reconnecte et
-- retrouve workspaces, onglets et splits.
--
-- Linux uniquement pour l'instant : sous Windows, le serveur tournerait côté
-- Windows et devrait lancer WSL lui-même ; non testé, donc désactivé.
if not IS_WINDOWS then
  config.unix_domains = { { name = "unix" } }
  config.default_gui_startup_args = { "connect", "unix" }
end

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

local BG = "#121212"
local ACTIVE_TAB_BG = "#00cc7a"
local INACTIVE_TAB_FG = "#f9f9f9"

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
config.show_new_tab_button_in_tab_bar = false
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
-- fenêtre n'a pas le focus.
wezterm.on("bell", function(window, pane)
  if window:is_focused() then
    return
  end
  local tab = pane:tab()
  local title = tab and tab:get_title() or ""
  if title == "" then
    title = pane:get_title()
  end
  window:toast_notification("WezTerm", "Terminé / en attente : " .. title, nil, 5000)
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
  table.insert(cells, { Background = { Color = BG } })
  table.insert(cells, { Foreground = { Color = ACTIVE_TAB_BG } })
  table.insert(cells, { Text = " " .. wezterm.nerdfonts.cod_window .. " " .. window:active_workspace() .. " " })
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
  { key = "t", mods = CA, action = act.SpawnTab("CurrentPaneDomain") },
  { key = "w", mods = CA, action = act.CloseCurrentTab({ confirm = false }) },

  -- Workspaces (un par session : de-session, ms-session...).
  { key = "s", mods = "CTRL|SHIFT", action = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES", title = "Workspaces" }) },
  { key = "PageDown", mods = "CTRL|ALT", action = act.SwitchWorkspaceRelative(1) },
  { key = "PageUp", mods = "CTRL|ALT", action = act.SwitchWorkspaceRelative(-1) },

  -- Recherche floue d'onglet, et sélection / échange de split par lettre
  -- (lettres de la rangée de repos BÉPO).
  { key = "o", mods = "CTRL|SHIFT", action = act.ShowTabNavigator },
  { key = "a", mods = CA, action = act.PaneSelect({ alphabet = "auietsrn" }) },
  { key = "x", mods = CA, action = act.PaneSelect({ alphabet = "auietsrn", mode = "SwapWithActive" }) },

  -- Ouvrir un ticket Linear visible à l'écran (MAR-xxxx) sans la souris.
  { key = "o", mods = CA, action = open_linear_ticket },

  -- Zoom du split actif (toggle_layout stack).
  { key = "z", mods = CA, action = act.TogglePaneZoomState },
}

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
