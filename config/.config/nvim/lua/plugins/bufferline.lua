-- Repère des onglets agent à droite de la barre du haut (les terminaux agents ne sont pas listés).
-- Tant qu'un onglet agent existe : barre toujours visible (bufferline la cache sinon quand
-- il n'y a qu'un buffer listé) et un repère cliquable « <n> Claude / opencode » par onglet agent.
local function agent_tabs()
  local res = {}
  for i, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local ok, v = pcall(vim.api.nvim_tabpage_get_var, tab, "ai_tab")
    if ok and (v == "claude" or v == "opencode") then
      table.insert(res, { nr = i, name = v, current = tab == vim.api.nvim_get_current_tabpage() })
    end
  end
  return res
end

-- bufferline relit config.options.always_show_bufferline à chaque rendu et sur BufAdd/TabEnter
-- (toggle_bufferline) : forcer vim.o.showtabline seul serait réécrasé. On pilote donc l'option.
local orig_always -- valeur d'origine (nil = pas encore mémorisée)
local function refresh()
  local ok, config = pcall(require, "bufferline.config")
  if not ok or not config.options then
    return
  end
  if orig_always == nil then
    orig_always = config.options.always_show_bufferline or false
  end
  local want = orig_always or #agent_tabs() > 0
  if config.options.always_show_bufferline ~= want then
    config.options.always_show_bufferline = want
  end
  if want then
    if vim.o.showtabline ~= 2 then
      vim.o.showtabline = 2
    end
  elseif not orig_always and vim.o.showtabline == 2 then
    pcall(function()
      local utils = require("bufferline.utils")
      local n = config:is_tabline() and utils.get_tab_count() or utils.get_buf_count()
      vim.o.showtabline = n > 1 and 2 or 0
    end)
  end
end

return {
  "akinsho/bufferline.nvim",
  opts = function(_, opts)
    opts.options = opts.options or {}
    local areas = opts.options.custom_areas or {}
    local prev_right = areas.right
    areas.right = function()
      -- pas de refresh() ici : modifier des options pendant le rendu de la tabline est risqué ;
      -- les autocmds ci-dessous (TabEnter, TabClosed, BufEnter...) s'en chargent.
      local res = {}
      if type(prev_right) == "function" then
        local ok, r = pcall(prev_right)
        if ok and type(r) == "table" then
          res = r
        end
      end
      for _, t in ipairs(agent_tabs()) do
        table.insert(res, {
          -- %<n>T : clic = aller à l'onglet n (syntaxe tabline native)
          text = ("%%%dT %d %s %%T"):format(t.nr, t.nr, t.name == "claude" and "Claude" or "opencode"),
          link = t.current and "TabLineSel" or "TabLine",
        })
      end
      return res
    end
    opts.options.custom_areas = areas

    vim.api.nvim_create_autocmd({ "TabEnter", "TabNewEntered", "TabClosed", "BufEnter", "WinEnter" }, {
      group = vim.api.nvim_create_augroup("ai_tab_bufferline_marker", { clear = true }),
      callback = function()
        vim.schedule(function()
          refresh()
          vim.cmd.redrawtabline()
        end)
      end,
    })
  end,
}
