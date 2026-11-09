-- Recharge les buffers modifies sur disque par les agents (claude / opencode).
--
-- Existant : `autoread` est actif (defaut nvim) et LazyVim lance `checktime` sur
-- FocusGained / TermClose / TermLeave seulement. Quand on reste dans nvim pendant que
-- l'agent ecrit, rien ne se declenchait. On ajoute :
--   * checktime sur BufEnter / WinEnter / TabEnter / FocusGained ;
--   * un timer leger (CHECK_MS) actif UNIQUEMENT tant qu'un terminal agent est vivant.
-- Un buffer modifie non sauvegarde n'est jamais ecrase : `autoread` natif previent et
-- demande, on ne force rien. Pas de checktime en mode commande ni dans la cmdwin.
local M = {}

local CHECK_MS = 1500
local timer = nil

M.timer_active = function()
  return timer ~= nil
end

local function safe_to_check()
  if vim.fn.getcmdwintype() ~= "" then
    return false
  end
  local mode = vim.api.nvim_get_mode().mode
  -- c = ligne de commande, r = prompt "Press ENTER"/confirm, ! = commande shell
  return not mode:match("^[cr!]")
end

M.check = function()
  if safe_to_check() then
    pcall(vim.cmd, "silent! checktime")
  end
end

local function stop()
  if timer then
    timer:stop()
    timer:close()
    timer = nil
  end
end

-- Demarre le timer si un agent est vivant, l'arrete sinon.
M.refresh = function()
  if require("config.ai_tab").agent_alive() then
    if not timer then
      timer = vim.uv.new_timer()
      timer:start(
        CHECK_MS,
        CHECK_MS,
        vim.schedule_wrap(function()
          if not require("config.ai_tab").agent_alive() then
            stop()
            return
          end
          M.check()
        end)
      )
    end
  else
    stop()
  end
end

M.setup = function()
  vim.o.autoread = true
  local group = vim.api.nvim_create_augroup("AgentReload", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "TabEnter", "FocusGained" }, {
    group = group,
    callback = function()
      if vim.bo.buftype ~= "nofile" and vim.bo.buftype ~= "terminal" then
        M.check()
      end
    end,
  })
  -- Un terminal vient de s'ouvrir / de mourir : (re)evaluer le timer apres que les modules
  -- agent aient enregistre leur buffer (snacks, claude.lua).
  vim.api.nvim_create_autocmd({ "TermOpen", "TermClose" }, {
    group = group,
    callback = function()
      vim.defer_fn(M.refresh, 300)
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", { group = group, callback = stop })
end

return M
