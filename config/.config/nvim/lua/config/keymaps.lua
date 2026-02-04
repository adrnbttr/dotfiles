-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--
local function save_file()
	vim.cmd("write") -- Exécute :w pour sauvegarder
end

-- Mapper la touche 'à' en mode insert pour sauvegarder et quitter le mode insert
vim.keymap.set("i", "à", function()
	vim.cmd("write") -- Sauvegarde
	vim.api.nvim_input("<Esc>") -- Quitte le mode insert
end, { noremap = true, silent = true, desc = "Save file and exit insert mode with 'à'" })

-- Mapper la touche 'à' en mode normal pour sauvegarder
vim.keymap.set("n", "à", function()
	save_file()
end, { noremap = true, silent = true, desc = "Save file with 'à' in normal mode" })

vim.keymap.set("n", "<leader>«", "<cmd>Telescope current_buffer_fuzzy_find<cr>", { desc = "Fuzzy find in current buffer" })

-- Layout-agnostic alternatives (works across BEPO/AZERTY)
vim.keymap.set({ "n", "i", "v" }, "<C-s>", function()
  vim.cmd("write")
end, { silent = true, desc = "Save file" })

vim.keymap.set("n", "<leader>w", function()
  vim.cmd("write")
end, { silent = true, desc = "Save file" })

vim.keymap.set("n", "<leader>sb", "<cmd>Telescope current_buffer_fuzzy_find<cr>", { desc = "Search in current buffer" })

vim.keymap.set("n", "<leader>sr", function()
  if vim.fn.exists(":GrugFar") == 2 then
    vim.cmd("GrugFar")
  else
    vim.notify("GrugFar not available", vim.log.levels.WARN)
  end
end, { desc = "Search/replace (grug-far)" })
