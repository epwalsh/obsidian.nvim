local abc = require "obsidian.abc"
local Path = require "plenary.path"

---@class obsidian.Workspace : obsidian.ABC
---@field name string
---@field path Path
---@field group number autocommand group id, used by `Workspace.register`
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
  self.path = Path:new(vim.fs.normalize(path))
  self.group = vim.api.nvim_create_augroup("obsidian_workspace_" .. string.lower(name), { clear = true })
  return self
end

---Create new workspace
--
---@param dir string
---@return obsidian.Workspace
Workspace.new_from_dir = function(dir)
  return Workspace.new(vim.fn.fnamemodify(dir, ":t"), dir)
end

--- register `cb` to be called whenever a buffer from this workspace is entered
--- all callbacks can be cleared with `Workspace:clear()`
---@param self obsidian.Workspace
---@param cb fun(cb: fun(event:any))
Workspace.register = function(self, cb)
  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    group = self.group,
    pattern = tostring(self.path / "**.md"),
    callback = cb
  })
end

--- Clear autocommands
---
---@param self obsidian.Workspace
Workspace.clear = function(self)
  vim.api.nvim_clear_autocmds({ group = self.group })
end

return Workspace
