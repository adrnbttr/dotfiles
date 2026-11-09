-- Neo-tree tweaks (LazyVim ships neo-tree by default)

-- Dans un onglet agent (vim.t.ai_tab), un fichier s'ouvre dans l'onglet de code ;
-- sinon (hors onglet agent, ou noeud non-fichier) : commande `open` de la source.
local function ai_tab_open(state)
  local node = state.tree and state.tree:get_node()
  if vim.t.ai_tab and node and node.type == "file" and node.path then
    require("config.ai_tab").open_in_code_tab(node.path)
    return
  end
  require("neo-tree.sources." .. state.name .. ".commands").open(state)
end

return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    -- Pinned: commits after f4102f5 (notably the #2002 reveal rework) introduced
    -- a regression where pressing <CR> on a folder expands then immediately
    -- collapses it. Revisit this pin after upstream fixes land.
    commit = "f4102f547165e7f8ad00f12c3c8e2e89f19a209d",
    opts = function(_, opts)
      opts.close_if_last_window = true
      -- apres l'autocmd WinClosed de neo-tree (plugin/ deja source) : on passe avant lui
      require("config.ai_tab").install_guard()
      opts.window = opts.window or {}
      opts.window.mappings = vim.tbl_deep_extend("force", opts.window.mappings or {}, {
        ["l"] = "ai_tab_open",
        ["<cr>"] = "ai_tab_open",
        ["<2-LeftMouse>"] = "ai_tab_open",
        ["h"] = "close_node",
      })
      opts.commands = vim.tbl_extend("force", opts.commands or {}, {
        ai_tab_open = ai_tab_open,
      })
    end,
  },
}
