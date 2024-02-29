local Workspace = require "obsidian.workspace"
local Path = require "obsidian.path"
local log = require "obsidian.log"
local util = require "obsidian.util"
local VERSION = require "obsidian.version"

---@param client obsidian.Client
return function(client, data)
  data = data or {}

  local info = util.get_plugin_info() or {}
  log.lazy_info("Obsidian.nvim v%s (%s)", VERSION, info.commit or "unknown commit")

  log.lazy_info "Status:"
  log.lazy_info("   buffer directory: %s", client.buf_dir)
  log.lazy_info("   working directory: %s", Path.cwd())

  log.lazy_info "Workspaces:"
  log.lazy_info("  ✓ active workspace: %s", client.current_workspace)
  for _, workspace_spec in ipairs(client.opts.workspaces) do
    local workspace = Workspace.new_from_spec(workspace_spec)
    if workspace ~= client.current_workspace then
      log.lazy_info("  ✗ inactive workspace: %s", workspace)
    end
  end

  log.lazy_info "Dependencies:"
  for _, plugin in ipairs { "plenary.nvim", "nvim-cmp", "telescope.nvim", "fzf-lua", "mini.pick" } do
    local plugin_info = util.get_plugin_info(plugin)
    if plugin_info ~= nil then
      log.lazy_info("   %s: %s", plugin, plugin_info.commit or "unknown")
    end
  end

  log.lazy_info "Integrations:"
  log.lazy_info("   picker: %s", client:picker())
  log.lazy_info("   completion: %s", client.opts.completion.nvim_cmp and "enabled (nvim-cmp)" or "disabled")

  log.lazy_info "Tools:"
  log.lazy_info("   rg: %s", util.get_external_dependency_info "rg" or "not found")

  log.lazy_info "Environment:"
  log.lazy_info("   operating system: %s", util.get_os())

  log.lazy_info "Config:"
  log.lazy_info("   notes_subdir: %s", client.opts.notes_subdir)

  log.flush { raw_print = data.raw_print }
end
