local M = {}

local TARGET_PATTERN = "/app/entrypoints/postgres/clients/"

local function has_dotenv()
  return vim.fn.exists("*DotenvGet") == 1
end

local function getenv(name)
  if has_dotenv() then
    local ok, val = pcall(vim.fn.DotenvGet, name)
    if ok and type(val) == "string" and val ~= "" then
      return val
    end
  end

  local val = vim.env[name]
  if type(val) == "string" and val ~= "" then
    return val
  end
  return nil
end

-- Percent-encode per RFC3986 (unreserved: ALPHA / DIGIT / "-" / "." / "_" / "~")
local function url_encode(str)
  if str == nil then
    return nil
  end
  return (tostring(str):gsub("([^%w%-%._~])", function(c)
    return string.format("%%%02X", string.byte(c))
  end))
end

local function is_sql_path(path)
  return type(path) == "string" and path:sub(-4) == ".sql"
end

local function extract_client_from_path(path)
  if type(path) ~= "string" then
    return nil
  end

  -- clients/**/<client>/sql/**/*.sql
  local middle = path:match("/app/entrypoints/postgres/clients/(.-)/sql/")
  if not middle or middle == "" then
    return nil
  end
  return middle:match("([^/]+)$")
end

local function extract_dbname_override_from_first_line(bufnr)
  local line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ""
  local dbname = line:match("^%s*%-%-%s*dbname:%s*(%S+)%s*$")
  return dbname
end

local function resolve_pg_vars(mode)
  local primary = mode == "local" and "POSTGRES_LOCAL_" or "POSTGRES_"
  local fallback = mode == "local" and "POSTGRES_" or "POSTGRES_LOCAL_"

  local function get(suffix)
    return getenv(primary .. suffix) or getenv(fallback .. suffix)
  end

  return {
    username = get("USERNAME"),
    password = get("PASSWORD"),
    host = get("HOST") or "localhost",
    port = get("PORT") or "5432",
  }
end

local function build_dsn(dbname, mode)
  local vars = resolve_pg_vars(mode)
  local username = vars.username
  local password = vars.password
  local host = vars.host
  local port = vars.port

  if password and not username then
    return nil, "POSTGRES_*_PASSWORD is set but username is missing"
  end

  local auth = ""
  if username and username ~= "" then
    auth = url_encode(username)
    if password and password ~= "" then
      auth = auth .. ":" .. url_encode(password)
    end
    auth = auth .. "@"
  end

  local dsn = string.format(
    "postgresql://%s%s:%s/%s",
    auth,
    host,
    port,
    url_encode(dbname)
  )

  return dsn, nil
end

function M.is_target_path(path)
  if not is_sql_path(path) then
    return false
  end
  if not path:find(TARGET_PATTERN, 1, true) then
    return false
  end
  return path:match("/app/entrypoints/postgres/clients/.*/sql/") ~= nil
end

function M.maybe_apply(bufnr, opts)
  opts = opts or {}
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local path = vim.api.nvim_buf_get_name(bufnr)
  if not M.is_target_path(path) then
    return nil
  end

  local dbname = extract_dbname_override_from_first_line(bufnr) or extract_client_from_path(path)
  if not dbname or dbname == "" then
    if not opts.silent then
      vim.notify("marvin-dadbod: could not determine dbname", vim.log.levels.WARN)
    end
    return nil
  end

  local mode = vim.g.marvin_db_mode or "prod"
  local dsn, err = build_dsn(dbname, mode)
  if not dsn then
    if not opts.silent then
      vim.notify("marvin-dadbod: " .. err, vim.log.levels.WARN)
    end
    return nil
  end

  vim.b[bufnr].db = dsn
  vim.b[bufnr].marvin_dbname = dbname
  vim.b[bufnr].marvin_db_mode = mode

  -- Export to DBUI (connections list) via g:dbs.
  -- DBUI reads connections from g:dbs / env / .env (DB_UI_*). Our project
  -- already derives the DSN from POSTGRES_* vars, so we mirror it here.
  local dbs = vim.g.dbs or {}
  local key = string.format("marvin_%s_%s", mode, dbname)
  dbs[key] = dsn
  vim.g.dbs = dbs

  -- If DBUI is already loaded, reset its cached state so the new connection
  -- appears when toggling/opening.
  pcall(vim.fn["db_ui#reset_state"])

  return dsn
end

function M.set_mode(mode)
  if mode ~= "local" and mode ~= "prod" then
    vim.notify("MarvinDbMode: expected 'local' or 'prod'", vim.log.levels.ERROR)
    return
  end
  vim.g.marvin_db_mode = mode
  M.maybe_apply(vim.api.nvim_get_current_buf(), { silent = true })
  vim.notify("Marvin DB mode: " .. mode, vim.log.levels.INFO)
end

return M
