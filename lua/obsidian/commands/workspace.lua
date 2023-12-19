local Path = require "plenary.path"
local log = require "obsidian.log"

---@param client obsidian.Client
return function(client, data)
  if not data.args or #data.args == 0 then
    log.info("Current workspace: " .. client.current_workspace.name .. " @ " .. tostring(client.dir))
    return
  end

  local workspace = nil
  for _, value in pairs(client.opts.workspaces) do
    if data.args == value.name then
      workspace = value
    end
  end

  if not workspace then
    log.err("Workspace '" .. data.args .. "' does not exist")
    return
  end

  client.current_workspace = workspace

  log.info("Switching to workspace '" .. workspace.name .. "' (" .. workspace.path .. ")")
  -- NOTE: workspace.path has already been normalized
  client.dir = Path:new(workspace.path)
end
