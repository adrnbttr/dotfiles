-- Neo-tree tweaks (LazyVim ships neo-tree by default)
return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = function(_, opts)
      -- Allow a single :q to exit Neovim when neo-tree is open.
      opts.close_if_last_window = true
    end,
  },
}
