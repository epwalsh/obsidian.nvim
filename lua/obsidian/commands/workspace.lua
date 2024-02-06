local log = require "obsidian.log"

---@param client obsidian.Client
return function(client, data)
  if not data.args or string.len(data.args) == 0 then
    log.info("Current workspace: '%s' @ '%s'", client.current_workspace.name, client.current_workspace.path)
    return
  else
    client:switch_workspace(data.args)
  end
end
