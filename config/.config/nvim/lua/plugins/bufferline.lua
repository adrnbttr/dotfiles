-- Repère d'onglet agent à droite de la barre du haut (les terminaux agents ne sont pas listés).
return {
  "akinsho/bufferline.nvim",
  opts = function(_, opts)
    opts.options = opts.options or {}
    local areas = opts.options.custom_areas or {}
    local prev_right = areas.right
    areas.right = function()
      local res = {}
      if type(prev_right) == "function" then
        local ok, r = pcall(prev_right)
        if ok and type(r) == "table" then
          res = r
        end
      end
      local ok, v = pcall(vim.api.nvim_tabpage_get_var, 0, "ai_tab")
      if ok and (v == "claude" or v == "opencode") then
        table.insert(res, { text = " " .. (v == "claude" and "Claude" or "opencode") .. " ", link = "TabLineSel" })
      end
      return res
    end
    opts.options.custom_areas = areas

    vim.api.nvim_create_autocmd({ "TabEnter", "TabNewEntered" }, {
      group = vim.api.nvim_create_augroup("ai_tab_bufferline_marker", { clear = true }),
      callback = function()
        vim.schedule(function()
          vim.cmd.redrawtabline()
        end)
      end,
    })
  end,
}
