-- LSP propres aux projets Marvin, en complément des extras de lazyvim.json.

-- docker-compose*.yml en `yaml.docker-compose` : active le LSP compose de
-- l'extra lang.docker (yamlls s'y attache aussi).
vim.filetype.add({
  pattern = {
    ["docker%-compose[%w%.%-]*%.ya?ml"] = "yaml.docker-compose",
    ["compose[%w%.%-]*%.ya?ml"] = "yaml.docker-compose",
  },
})

-- Interpréteur Python du projet pour pyright : .venv local, sinon le virtualenv
-- poetry (rangé dans ~/.cache/pypoetry, introuvable seul par pyright). Chaque
-- worktree data-engineering a le sien. Résultat mis en cache par racine.
local python_by_root = {}

local function project_python(root)
  if python_by_root[root] == nil then
    local python = false
    local local_venv = root .. "/.venv/bin/python"
    if vim.uv.fs_stat(local_venv) then
      python = local_venv
    elseif vim.uv.fs_stat(root .. "/poetry.lock") and vim.fn.executable("poetry") == 1 then
      local out = vim.fn.system({ "poetry", "-C", root, "env", "info", "-p" })
      local venv = vim.trim(out)
      if vim.v.shell_error == 0 and vim.uv.fs_stat(venv .. "/bin/python") then
        python = venv .. "/bin/python"
      end
    end
    python_by_root[root] = python
  end
  return python_by_root[root] or nil
end

return {
  -- debugpy : utilisé par nvim-dap-python (extra lang.python + nvim-dap de
  -- dap.lua) pour déboguer data-engineering (<leader>dPt : test sous le curseur).
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "debugpy" } },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        pyright = {
          before_init = function(_, config)
            local python = config.root_dir and project_python(config.root_dir)
            if python then
              -- Modifié en place : le client garde une référence à cette table.
              config.settings = config.settings or {}
              config.settings.python = config.settings.python or {}
              config.settings.python.pythonPath = python
            end
          end,
        },
        -- oxlint (linter de marvin-suite) en LSP : diagnostics et `:LspOxlintFixAll`.
        -- Le binaire vient du projet (node_modules/.bin/oxlint), pas de Mason.
        -- marvin-suite nomme sa config `oxlint.json` (lancée avec `oxlint -c
        -- oxlint.json`), que les marqueurs par défaut (.oxlintrc.json) ignorent.
        oxlint = {
          mason = false,
          root_markers = { "oxlint.json", ".oxlintrc.json", ".oxlintrc.jsonc", "oxlint.config.ts" },
          settings = {
            configPath = "oxlint.json",
          },
        },
      },
    },
  },
}
