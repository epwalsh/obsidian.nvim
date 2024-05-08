local Path = require "obsidian.path"
local abc = require "obsidian.abc"

---@class obsidian.workspace.WorkspaceSpec
---
---@field path string|obsidian.Path|(fun(): string|obsidian.Path)
---@field name string|?
---@field strict boolean|? If true, the workspace root will be fixed to 'path' instead of the vault root (if different).
---@field overrides table|obsidian.config.ClientOpts|?

---@class obsidian.workspace.WorkspaceOpts
---
---@field name string|?
---@field strict boolean|? If true, the workspace root will be fixed to 'path' instead of the vault root (if different).
---@field overrides table|obsidian.config.ClientOpts|?

--- Each workspace represents a working directory (usually an Obsidian vault) along with
--- a set of configuration options specific to the workspace.
---
--- Workspaces are a little more general than Obsidian vaults as you can have a workspace
--- outside of a vault or as a subdirectory of a vault.
---
---@toc_entry obsidian.Workspace
---
---@class obsidian.Workspace : obsidian.ABC
---
---@field name string An arbitrary name for the workspace.
---@field path obsidian.Path The normalized path to the workspace.
---@field root obsidian.Path The normalized path to the vault root of the workspace. This usually matches 'path'.
---@field overrides table|obsidian.config.ClientOpts|?
---@field locked boolean|?
local Workspace = abc.new_class {
  __tostring = function(self)
    return string.format("Workspace(name='%s', path='%s', root='%s')", self.name, self.path, self.root)
  end,
  __eq = function(a, b)
    local a_fields = a:as_tbl()
    a_fields.locked = nil
    local b_fields = b:as_tbl()
    b_fields.locked = nil
    return vim.deep_equal(a_fields, b_fields)
  end,
}

--- Find the vault root from a given directory.
---
--- This will traverse the directory tree upwards until a '.obsidian/' folder is found to
--- indicate the root of a vault, otherwise the given directory is used as-is.
---
---@param base_dir string|obsidian.Path
---
---@return obsidian.Path|?
local function find_vault_root(base_dir)
  local vault_indicator_folder = ".obsidian"
  base_dir = Path.new(base_dir)
  local dirs = Path.new(base_dir):parents()
  table.insert(dirs, 1, base_dir)

  for _, dir in ipairs(dirs) do
    local maybe_vault = dir / vault_indicator_folder
    if maybe_vault:is_dir() then
      return dir
    end
  end

  return nil
end

--- Create a new 'Workspace' object. This assumes the workspace already exists on the filesystem.
---
---@param path string|obsidian.Path Workspace path.
---@param opts obsidian.workspace.WorkspaceOpts|?
---
---@return obsidian.Workspace
Workspace.new = function(path, opts)
  opts = opts and opts or {}

  local self = Workspace.init()
  self.path = Path.new(path):resolve { strict = true }
  self.name = assert(opts.name or self.path.name)
  self.overrides = opts.overrides

  if opts.strict then
    self.root = self.path
  else
    local vault_root = find_vault_root(self.path)
    if vault_root then
      self.root = vault_root
    else
      self.root = self.path
    end
  end

  return self
end

--- Initialize a new 'Workspace' object from a workspace spec.
---
---@param spec obsidian.workspace.WorkspaceSpec
---
---@return obsidian.Workspace
Workspace.new_from_spec = function(spec)
  ---@type string|obsidian.Path
  local path
  if type(spec.path) == "function" then
    path = spec.path()
  else
    ---@diagnostic disable-next-line: cast-local-type
    path = spec.path
  end

  ---@diagnostic disable-next-line: param-type-mismatch
  return Workspace.new(path, {
    name = spec.name,
    strict = spec.strict,
    overrides = spec.overrides,
  })
end

--- Initialize a 'Workspace' object from the current working directory.
---
---@param opts obsidian.workspace.WorkspaceOpts|?
---
---@return obsidian.Workspace
Workspace.new_from_cwd = function(opts)
  local cwd = assert(vim.fn.getcwd())
  return Workspace.new(cwd, opts)
end

--- Initialize a 'Workspace' object from the parent directory of the current buffer.
---
---@param bufnr integer|?
---@param opts obsidian.workspace.WorkspaceOpts|?
---
---@return obsidian.Workspace
Workspace.new_from_buf = function(bufnr, opts)
  local bufdir = Path.buf_dir(bufnr)
  return Workspace.new(bufdir, opts)
end

--- Lock the workspace.
Workspace.lock = function(self)
  self.locked = true
end

--- Unlock the workspace.
Workspace._unlock = function(self)
  self.locked = false
end

--- Get the workspace corresponding to the directory (or a parent of), if there
--- is one.
---
---@param cur_dir string|obsidian.Path
---@param workspaces obsidian.workspace.WorkspaceSpec[]
---
---@return obsidian.Workspace|?
Workspace.get_workspace_for_dir = function(cur_dir, workspaces)
  local ok
  ok, cur_dir = pcall(function()
    return Path.new(cur_dir):resolve { strict = true }
  end)

  if not ok then
    return
  end

  for _, spec in ipairs(workspaces) do
    local w = Workspace.new_from_spec(spec)
    if w.path == cur_dir or w.path:is_parent_of(cur_dir) then
      return w
    end
  end
end

--- Get the workspace corresponding to the current working directory (or a parent of), if there
--- is one.
---
---@param workspaces obsidian.workspace.WorkspaceSpec[]
---
---@return obsidian.Workspace|?
Workspace.get_workspace_for_cwd = function(workspaces)
  local cwd = assert(vim.fn.getcwd())
  return Workspace.get_workspace_for_dir(cwd, workspaces)
end

--- Returns the default workspace.
---
---@param workspaces obsidian.workspace.WorkspaceSpec[]
---
---@return obsidian.Workspace|nil
Workspace.get_default_workspace = function(workspaces)
  if not vim.tbl_isempty(workspaces) then
    return Workspace.new_from_spec(workspaces[1])
  else
    return nil
  end
end

--- Resolves current workspace from the client config.
---
---@param opts obsidian.config.ClientOpts
---
---@return obsidian.Workspace|?
Workspace.get_from_opts = function(opts)
  local current_workspace = Workspace.get_workspace_for_cwd(opts.workspaces)

  if not current_workspace then
    current_workspace = Workspace.get_default_workspace(opts.workspaces)
  end

  return current_workspace
end

return Workspace
