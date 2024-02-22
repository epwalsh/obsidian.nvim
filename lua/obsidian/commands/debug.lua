local Workspace = require "obsidian.workspace"
local log = require "obsidian.log"

---@param client obsidian.Client
return function(client)
  log.lazy_info "Status:"
  log.lazy_info("  Buffer directory: '%s'", client.buf_dir and client.buf_dir or "nil")
  log.lazy_info("  Working directory: '%s'", vim.fn.getcwd())

  log.lazy_info "Workspaces:"
  log.lazy_info("  Active workspace: %s", client.current_workspace)
  for _, workspace_spec in ipairs(client.opts.workspaces) do
    local workspace = Workspace.new_from_spec(workspace_spec)
    if workspace ~= client.current_workspace then
      log.lazy_info("  Inactive workspace: %s", workspace)
    end
  end

  log.lazy_info "Config:"
  log.lazy_info("  notes_subdir: '%s'", client.opts.notes_subdir and client.opts.notes_subdir or "nil")

  log.flush()
end
