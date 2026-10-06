-- Codex (OpenAI) dans un split terminal, sur le préfixe <leader>w.
-- Même principe que Claude (<leader>z) et opencode (<leader>j).
-- Note : <leader>w seul (sauvegarde) attend 'timeoutlen' puisque <leader>wt existe.

local function codex_term()
  return Snacks.terminal.get("codex", {
    cwd = vim.fn.getcwd(),
    win = { position = "right", width = 0.4 },
    create = false,
  })
end

local function codex_send(text)
  Snacks.terminal.toggle("codex", { win = { position = "right", width = 0.4 } })
  vim.defer_fn(function()
    local term = codex_term()
    local job = term and vim.b[term.buf].terminal_job_id
    if job then
      vim.fn.chansend(job, text .. "\n")
    end
  end, 400)
end

local function visual_selection()
  local reg_save = vim.fn.getreg('"')
  vim.cmd("noau normal! y")
  local text = vim.fn.getreg('"')
  vim.fn.setreg('"', reg_save)
  return text
end

return {
  {
    "folke/snacks.nvim",
    opts = { terminal = {} },
    keys = {
      {
        "<leader>wt",
        function()
          if vim.fn.executable("codex") ~= 1 then
            vim.notify("codex: CLI introuvable — ./script/install --only codex", vim.log.levels.WARN)
            return
          end
          Snacks.terminal.toggle("codex", { win = { position = "right", width = 0.4 } })
        end,
        mode = { "n", "t" },
        desc = "Codex: Toggle split",
      },
      {
        "<leader>wa",
        function()
          vim.ui.input({ prompt = "Ask Codex: " }, function(input)
            if input and #input > 0 then
              codex_send(input)
            end
          end)
        end,
        desc = "Codex: Ask (input)",
      },
      {
        "<leader>wa",
        function()
          local sel = visual_selection()
          if sel and #sel > 0 then
            vim.ui.input({ prompt = "Ask about selection: " }, function(input)
              codex_send((input and #input > 0 and (input .. "\n\n") or "") .. "```\n" .. sel .. "\n```")
            end)
          end
        end,
        mode = "x",
        desc = "Codex: Ask about selection",
      },
    },
  },
}
