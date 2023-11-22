local abc = require "obsidian.abc"

---@class obsidian.Workspace : obsidian.ABC
---@field name string
---@field path string
local Workspace = abc.new_class {
  __tostring = function(self)
    return string.format("Workspace('%s', '%s')", self.name, self.path)
  end,
}

---Create a new workspace
---
---@param name string Workspace name
---@param path string Workspace path (will be normalized)
---
---@return obsidian.Workspace
Workspace.new = function(name, path)
  local self = Workspace.init()
  self.name = name
  self.path = vim.fs.normalize(path)
  return self
end

Workspace.new_from_cwd = function()
  return Workspace.new_from_dir(vim.fn.getcwd())
end

Workspace.new_from_dir = function(dir)
  return Workspace.new(vim.fn.fnamemodify(dir, ":t"), dir)
end

---Determines if cwd is a workspace
---
---@param workspaces table<obsidian.Workspace>
---@return obsidian.Workspace|nil
Workspace.get_workspace_from_cwd = function(workspaces)
  local cwd = vim.fn.getcwd()
  local _, value = next(vim.tbl_filter(function(w)
    if w.path == cwd then
      return true
    end
    return false
  end, workspaces))

  return value
end

---Returns the default workspace
---
---@param workspaces table<obsidian.Workspace>
---@return obsidian.Workspace|nil
Workspace.get_default_workspace = function(workspaces)
  local _, value = next(workspaces)
  return value
end

---Resolves current workspace from client config
---
---@param opts obsidian.config.ClientOpts
---@return obsidian.Workspace
Workspace.get_from_opts = function(opts)
  local current_workspace

  if opts.detect_cwd then
    current_workspace = Workspace.get_workspace_from_cwd(opts.workspaces)
  else
    current_workspace = Workspace.get_default_workspace(opts.workspaces)
  end

  if not current_workspace then
    current_workspace = Workspace.new_from_cwd()
  end

  return current_workspace
end

return Workspace
