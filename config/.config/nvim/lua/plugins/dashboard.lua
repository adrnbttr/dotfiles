-- Page d'accueil : « HELLO » en demi-blocs + curseur fixe, à côté d'une baleine (hello whales),
-- puis deux lignes façon boot Linux avec de vraies valeurs (dossier courant et branche git,
-- utilisateur). Les raccourcis (keys) et la ligne startup
-- du dashboard LazyVim restent tels quels, dessous.
-- Toutes les lignes de l'en-tête sont complétées à la même largeur d'affichage : le bloc est centré
-- d'un seul tenant et aligné à gauche. Couleurs : groupes snacks existants (Header / Desc).

-- HELLO en demi-blocs (3 lignes, terminé par le curseur fixe ▀▀) à côté d'une petite baleine avec un petit jet d'eau.
local hello = {
  [[                                      ▀▄▀]],
  [[█   █ █▀▀▀▀ █     █     ▄▀▀▀▄       ▄███████▄▄   ▄▄]],
  [[█▀▀▀█ █▀▀▀  █     █     █   █      ██▀█████████▄▀▀]],
  [[▀   ▀ ▀▀▀▀▀ ▀▀▀▀▀ ▀▀▀▀▀  ▀▀▀  ▀▀    ▀█████████▀]],
}

local function git_branch()
  local out = vim.fn.systemlist({ "git", "-C", vim.fn.getcwd(), "branch", "--show-current" })
  if vim.v.shell_error ~= 0 or not out[1] or out[1] == "" then
    return nil
  end
  return out[1]
end

local function boot_line(parts)
  local text = { { "[  ", hl = "desc" }, { "OK", hl = "header" }, { "  ] ", hl = "desc" } }
  for _, p in ipairs(parts) do
    text[#text + 1] = { p, hl = "desc" }
  end
  return text
end

local function header_sections()
  local session = vim.fn.fnamemodify(vim.fn.getcwd(), ":~")
  local branch = git_branch()
  if branch then
    session = session .. " (" .. branch .. ")"
  end

  ---@type table[][]
  local rows = {}
  for i, l in ipairs(hello) do
    rows[i] = { { l, hl = "header" } }
  end
  rows[#rows + 1] = { { "" } }
  rows[#rows + 1] = boot_line({ "session: " .. session })
  rows[#rows + 1] = boot_line({ "user: " .. (vim.env.USER or vim.uv.os_get_passwd().username or "?") })

  local function row_width(r)
    local w = 0
    for _, t in ipairs(r) do
      w = w + vim.fn.strdisplaywidth(t[1])
    end
    return w
  end
  local width = 0
  for _, r in ipairs(rows) do
    width = math.max(width, row_width(r))
  end

  local sections = {}
  for i, r in ipairs(rows) do
    r[#r + 1] = { (" "):rep(width - row_width(r)), hl = "desc" }
    sections[i] = { align = "center", text = r, padding = i == #rows and 2 or 0 }
  end
  return sections
end

return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    opts.dashboard = opts.dashboard or {}
    opts.dashboard.sections = {
      header_sections,
      { section = "keys", gap = 1, padding = 1 },
      { section = "startup" },
    }
  end,
}
