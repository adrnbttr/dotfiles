-- Neo-tree tweaks (LazyVim ships neo-tree by default)
return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    -- Pinned: commits after f4102f5 (notably the #2002 reveal rework) introduced
    -- a regression where pressing <CR> on a folder expands then immediately
    -- collapses it. Revisit this pin after upstream fixes land.
    commit = "f4102f547165e7f8ad00f12c3c8e2e89f19a209d",
    opts = function(_, opts)
      opts.close_if_last_window = true
      opts.window = opts.window or {}
      opts.window.mappings = vim.tbl_deep_extend("force", opts.window.mappings or {}, {
        ["l"] = "open",
        ["h"] = "close_node",
      })
    end,
  },
}
