---@class obsidian.Workspace
---@field name string
---@field path string
---@return obsidian.Workspace
local workspace = {}

---Create a new workspace
---
---@param name string Workspace name
---@param path string Workspace path (will be normalized)
---
---@return obsidian.Workspace
workspace.new = function(name, path)
  local self = setmetatable({}, { __index = workspace })

  self.name = name
  self.path = vim.fs.normalize(path)

  return self
end

workspace.new_from_cwd = function()
  return workspace.new(".", vim.fn.getcwd())
end

workspace.new_from_dir = function(dir)
  return workspace.new(vim.fn.fnamemodify(dir, ":t"), dir)
end

---Determines if cwd is a workspace
---
---@param workspaces table<obsidian.Workspace>
---@return obsidian.Workspace|nil
workspace.get_workspace_from_cwd = function(workspaces)
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
workspace.get_default_workspace = function(workspaces)
  local _, value = next(workspaces)
  return value
end

---Resolves current workspace from client config
---
---@param opts obsidian.config.ClientOpts
---@return obsidian.Workspace
workspace.get_from_opts = function(opts)
  local current_workspace

  if opts.detect_cwd then
    current_workspace = workspace.get_workspace_from_cwd(opts.workspaces)
  else
    current_workspace = workspace.get_default_workspace(opts.workspaces)
  end

  if not current_workspace then
    current_workspace = workspace.new_from_cwd()
  end

  return current_workspace
end

return workspace
