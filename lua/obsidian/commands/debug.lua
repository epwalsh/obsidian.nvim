local Workspace = require "obsidian.workspace"
local log = require "obsidian.log"

---@param client obsidian.Client
return function(client)
  log.lazy_info "Status:"
  log.lazy_info("  Buffer directory: '%s'", client.buf_dir)
  log.lazy_info("  Working directory: '%s'", vim.fn.getcwd())

  log.lazy_info "Workspaces:"
  local cur_workspace = Workspace.get_workspace_for_dir(client.buf_dir, client.opts.workspaces)
  if cur_workspace ~= nil then
    log.lazy_info("  Active workspace: %s", cur_workspace)
  else
    log.lazy_info "  No active workspaces"
  end

  for _, workspace_spec in ipairs(client.opts.workspaces) do
    local workspace = Workspace.new_from_spec(workspace_spec)
    if workspace ~= cur_workspace then
      log.lazy_info("  Inactive workspace: %s", workspace)
    end
  end

  log.lazy_info "Config:"
  log.lazy_info("  notes_subdir: '%s'", client.opts.notes_subdir)

  log.flush()
end
