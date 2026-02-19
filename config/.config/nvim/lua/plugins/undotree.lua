-- Undotree: Visual undo history tree
return {
  {
    "mbbill/undotree",
    keys = {
      { "<leader>u", "<cmd>UndotreeToggle<cr>", desc = "Toggle undotree" },
    },
    config = function()
      vim.g.undotree_WindowLayout = 2
      vim.g.undotree_SplitWidth = 40
      vim.g.undotree_DiffpanelHeight = 10
      vim.g.undotree_SetFocusWhenToggle = 1
      vim.g.undotree_TreeVertShape = "│"
      vim.g.undotree_TreeSplitShape = "╱"
      vim.g.undotree_TreeReturnShape = "╲"
    end,
  },
}
