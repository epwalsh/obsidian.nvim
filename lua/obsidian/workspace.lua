local Path = require "plenary.path"
local abc = require "obsidian.abc"

---@class obsidian.Workspace : obsidian.ABC
---@field name string
---@field path string
---@field overrides table|obsidian.config.ClientOpts|?
local Workspace = abc.new_class {
  __tostring = function(self)
    return string.format("Workspace('%s', '%s')", self.name, self.path)
  end,
}

---Create a new workspace
---
---@param name string Workspace name
---@param path string|Path Workspace path (will be normalized)
---@param overrides table|obsidian.config.ClientOpts|?
---@return obsidian.Workspace
Workspace.new = function(name, path, overrides)
  local self = Workspace.init()
  self.name = name
  self.path = vim.fs.normalize(tostring(path))
  self.overrides = overrides
  return self
end

---@return obsidian.Workspace
Workspace.new_from_cwd = function()
  -- First traverse upwards to find the root of the obsidian vault.
  -- If found, use that, otherwise use the current directory as is.
  local vault_indicator_folder = ".obsidian"
  local cwd = assert(vim.fn.getcwd())
  local dirs = Path:new(cwd):parents()
  table.insert(dirs, 1, cwd)

  for _, dir in ipairs(dirs) do
    local maybe_vault = Path:new(dir) / vault_indicator_folder
    if maybe_vault:is_dir() then
      return Workspace.new_from_dir(dir)
    end
  end

  return Workspace.new_from_dir(cwd)
end

---@param dir string|Path
---@return obsidian.Workspace
Workspace.new_from_dir = function(dir)
  return Workspace.new(assert(vim.fs.basename(tostring(dir))), dir)
end

---Get the workspace corresponding to the current working directory (or a parent of), if there
---is one.
---
---@param workspaces obsidian.Workspace[]
---@return obsidian.Workspace|?
Workspace.get_workspace_from_cwd = function(workspaces)
  local cwd = assert(vim.fn.getcwd())
  local dirs = Path:new(cwd):parents()
  table.insert(dirs, 1, cwd)

  for _, w in ipairs(workspaces) do
    for _, dir in ipairs(dirs) do
      if w.path == dir then
        return w
      end
    end
  end

  return nil
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
