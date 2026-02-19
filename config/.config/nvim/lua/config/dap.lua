-- DAP configuration with automatic port detection for Docker Node.js debugging

local M = {}

-- Function to scan for open debug ports
local function scan_debug_ports()
  local ports = {}
  
  -- Try to find Node.js inspector ports using netstat/ss
  local cmd = "ss -tlnp 2>/dev/null | grep -E '567[0-9]{2}' | awk '{print $4}' | sed 's/.*://'"
  
  -- Alternative: use lsof if ss is not available
  local handle = io.popen(cmd)
  if not handle then
    -- Try alternative command
    cmd = "lsof -iTCP -sTCP:LISTEN -P 2>/dev/null | grep -E '567[0-9]{2}' | awk '{print $9}' | sed 's/.*://'"
    handle = io.popen(cmd)
  end
  
  if handle then
    local result = handle:read("*a")
    handle:close()
    
    -- Parse ports from result
    for port in result:gmatch("%d+") do
      local port_num = tonumber(port)
      if port_num and port_num >= 56700 and port_num <= 56800 then
        table.insert(ports, port_num)
      end
    end
  end
  
  -- Also check common Docker ports from docker ps
  cmd = "docker ps --format '{{.Ports}}' 2>/dev/null | grep -oE '0\\.0\\.0\\.0:[0-9]+' | sed 's/.*://'"
  handle = io.popen(cmd)
  if handle then
    local result = handle:read("*a")
    handle:close()
    
    for port in result:gmatch("%d+") do
      local port_num = tonumber(port)
      if port_num and port_num >= 56700 and port_num <= 56800 then
        -- Check if not already in list
        local exists = false
        for _, existing_port in ipairs(ports) do
          if existing_port == port_num then
            exists = true
            break
          end
        end
        if not exists then
          table.insert(ports, port_num)
        end
      end
    end
  end
  
  return ports
end

-- Function to start debugging with port selection
function M.start_debug()
  local dap = require("dap")
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  
  -- Scan for available ports
  local ports = scan_debug_ports()
  
  -- Always add default ports
  table.insert(ports, 1, 56745)
  table.insert(ports, 2, 56746)
  
  -- Remove duplicates
  local unique_ports = {}
  local seen = {}
  for _, port in ipairs(ports) do
    if not seen[port] then
      seen[port] = true
      table.insert(unique_ports, port)
    end
  end
  
  if #unique_ports == 1 then
    -- Only one port found, connect directly
    local config = {
      type = 'node2',
      request = 'attach',
      name = 'Attach to Docker Node Process (port ' .. unique_ports[1] .. ')',
      port = unique_ports[1],
      restart = true,
      sourceMaps = true,
      skipFiles = { '<node_internals>/**' },
      localRoot = vim.fn.getcwd(),
      remoteRoot = '/app',
    }
    dap.run(config)
    vim.notify("Connecting to debug port " .. unique_ports[1], vim.log.levels.INFO)
  elseif #unique_ports > 1 then
    -- Multiple ports found, show picker
    local opts = {
      prompt_title = "Select Debug Port",
      finder = finders.new_table({
        results = unique_ports,
        entry_maker = function(port)
          return {
            value = port,
            display = "Port " .. port .. (port == 56745 and " (default)" or ""),
            ordinal = tostring(port),
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            local config = {
              type = 'node2',
              request = 'attach',
              name = 'Attach to Docker Node Process (port ' .. selection.value .. ')',
              port = selection.value,
              restart = true,
              sourceMaps = true,
              skipFiles = { '<node_internals>/**' },
              localRoot = vim.fn.getcwd(),
              remoteRoot = '/app',
            }
            dap.run(config)
            vim.notify("Connecting to debug port " .. selection.value, vim.log.levels.INFO)
          end
        end)
        return true
      end,
    }
    pickers.new(opts):find()
  else
    -- No ports found, ask for manual input
    vim.ui.input({
      prompt = "No debug ports detected. Enter port manually: ",
      default = "56745",
    }, function(input)
      if input and input ~= "" then
        local port = tonumber(input)
        if port then
          local config = {
            type = 'node2',
            request = 'attach',
            name = 'Attach to Docker Node Process (port ' .. port .. ')',
            port = port,
            restart = true,
            sourceMaps = true,
            skipFiles = { '<node_internals>/**' },
            localRoot = vim.fn.getcwd(),
            remoteRoot = '/app',
          }
          dap.run(config)
          vim.notify("Connecting to debug port " .. port, vim.log.levels.INFO)
        else
          vim.notify("Invalid port number", vim.log.levels.ERROR)
        end
      end
    end)
  end
end

-- Function to get current debug port (for statusline)
function M.get_current_port()
  local session = require("dap").session()
  if session then
    return session.config.port
  end
  return nil
end

-- Function to check if debugging is active
function M.is_debugging()
  return require("dap").session() ~= nil
end

return M
