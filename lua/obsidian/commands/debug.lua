local Workspace = require "obsidian.workspace"
local Path = require "obsidian.path"
local log = require "obsidian.log"

---@param client obsidian.Client
return function(client)
  log.lazy_info "Status:"
  log.lazy_info("  Buffer directory: '%s'", tostring(client.buf_dir))
  log.lazy_info("  Working directory: '%s'", Path.cwd())

  log.lazy_info "Workspaces:"
  log.lazy_info("  Active workspace: %s", client.current_workspace)
  for _, workspace_spec in ipairs(client.opts.workspaces) do
    local workspace = Workspace.new_from_spec(workspace_spec)
    if workspace ~= client.current_workspace then
      log.lazy_info("  Inactive workspace: %s", workspace)
    end
  end

  log.lazy_info "Config:"
  log.lazy_info("  notes_subdir: '%s'", tostring(client.opts.notes_subdir))

  log.flush()
end
