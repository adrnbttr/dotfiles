-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Avante UI polish
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "Avante" },
  callback = function()
    -- Evite le scroll horizontal dans la reponse
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.breakindent = true
    vim.opt_local.showbreak = "  "
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "AvanteInput" },
  callback = function(ev)
    -- Input plus agreable (longues lignes + retours)
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true

    -- Dans la config Avante, <CR> en insert = submit.
    -- On garde un moyen simple d'inserer une nouvelle ligne.
    local function insert_newline()
      local cr = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
      -- non-remap: insere un vrai retour a la ligne sans declencher le submit
      vim.api.nvim_feedkeys(cr, "n", false)
    end

    -- Fallback universel
    vim.keymap.set("i", "<C-j>", insert_newline, { buffer = ev.buf, silent = true })

    -- Kitty peut distinguer Shift-Enter (si kitty keyboard protocol est actif)
    vim.keymap.set("i", "<S-CR>", insert_newline, { buffer = ev.buf, silent = true })
    vim.keymap.set("i", "<S-Enter>", insert_newline, { buffer = ev.buf, silent = true })
  end,
})
