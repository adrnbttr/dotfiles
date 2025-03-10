return {
  {
    "github/copilot.vim",
    config = function()
      -- Activer Copilot au démarrage
      vim.g.copilot_no_tab_map = true
      vim.api.nvim_set_keymap("i", "<C-l>", 'copilot#Accept("<CR>")', { silent = true, expr = true })
    end,
  },
  {
    "lukas-reineke/indent-blankline.nvim",
    enabled = false
  }
}
