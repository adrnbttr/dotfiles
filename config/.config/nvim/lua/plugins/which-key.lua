-- Groupes which-key des agents (fusionnés avec la spec LazyVim, sans l'écraser).
return {
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>z", group = "Claude", icon = { icon = "󰚩 ", color = "orange" } },
        { "<leader>j", group = "opencode", icon = { icon = "󰚩 ", color = "cyan" } },
      },
    },
  },
}
