local log = require "obsidian.log"
local Workspace = require "obsidian.workspace"

---@param client obsidian.Client
return function(client, data)
  if not data.args or string.len(data.args) == 0 then
    local picker = client:picker()
    if not picker then
      log.info("Current workspace: '%s' @ '%s'", client.current_workspace.name, client.current_workspace.path)
      return
    end

    local options = {}
    for i, spec in ipairs(client.opts.workspaces) do
      local workspace = Workspace.new_from_spec(spec)
      if workspace == client.current_workspace then
        options[#options + 1] = string.format("*[%d] %s @ '%s'", i, workspace.name, workspace.path)
      else
        options[#options + 1] = string.format("[%d] %s @ '%s'", i, workspace.name, workspace.path)
      end
    end

    picker:pick(options, {
      prompt_title = "Workspaces",
      callback = function(workspace_str)
        local idx = tonumber(string.match(workspace_str, "%*?%[(%d+)]"))
        client:switch_workspace(client.opts.workspaces[idx].name, { lock = true })
      end,
    })
  else
    client:switch_workspace(data.args, { lock = true })
  end
end
