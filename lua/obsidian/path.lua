local abc = require "obsidian.abc"

local is_path_obj = function(path)
  if type(path) == "table" and path.__is_obsidian_path then
    return true
  else
    return false
  end
end

---@class obsidian.Path : obsidian.ABC
---
---@field filename string
---@field __is_obsidian_path boolean
local Path = abc.new_class {
  __tostring = function(self)
    return self.filename
  end,
}

--- Create a new path.
---
---@return obsidian.Path
Path.new = function(...)
  local args = { ... }

  local self = Path.init()

  local arg
  if #args == 1 then
    arg = tostring(args[1])
  elseif #args == 2 then
    arg = tostring(args[2])
  else
    error "expected one argument"
  end

  if is_path_obj(arg) then
    ---@cast arg obsidian.Path
    return arg
  end

  self.filename = vim.fs.normalize(tostring(arg))
  self.__is_obsidian_path = true

  return self
end

Path.mt.__eq = function(a, b)
  return a.filename == b.filename
end

Path.mt.__div = function(self, other)
  other = Path.new(other)
  return Path.new(vim.fs.joinpath(self.filename, other.filename))
end

--- Get the final path component, if any.
---
---@return string|?
Path.name = function(self)
  return vim.fs.basename(self.filename)
end

--- The final file extension, if any.
---
---@return string|?
Path.suffix = function(self)
  local _, _, ext = string.find(self.filename, "(%.[^%.]+)$")
  return ext
end

--- The final path component, without its suffix.
---
---@return string|?
Path.stem = function(self)
  local name, suffix = self:name(), self:suffix()
  if not name then
    return
  elseif not suffix then
    return name
  else
    return string.sub(name, 1, string.len(name) - string.len(suffix))
  end
end

--- Returns true if the path is already in absolute form.
---
---@return boolean
Path.is_absolute = function(self)
  if vim.startswith(self.filename, "/") or string.match(self.filename, "^[%a]:/.*$") then
    return true
  else
    return false
  end
end

--- Try to resolve a version of the path relative to the other.
--- An error is raised when it's not possible.
---
---@param other obsidian.Path|string
---
---@return obsidian.Path
Path.relative_to = function(self, other)
  if not self:is_absolute() then
    return self
  end

  other = Path.new(other)
  if vim.startswith(self.filename, other.filename .. "/") then
    return Path.new(string.sub(self.filename, string.len(other.filename) + 2))
  else
    error(string.format("'%s' is not in the subpath of '%s'", self.filename, other.filename))
  end
end

--- The logical parent of the path.
---
---@return obsidian.Path|?
Path.parent = function(self)
  local parent = vim.fs.dirname(self.filename)
  if parent ~= nil then
    return Path.new(parent)
  else
    return nil
  end
end

--- Get a list of the parent directories.
---
---@return obsidian.Path[]
Path.parents = function(self)
  local parents = {}
  for parent in vim.fs.parents(self.filename) do
    table.insert(parents, Path.new(parent))
  end
  return parents
end

--- Check if the path is a parent of other.
---
---@param other obsidian.Path|string
---
---@return boolean
Path.is_parent_of = function(self, other)
  local resolved = self:resolve()
  other = Path.new(other):resolve()
  for _, parent in ipairs(other:parents()) do
    if parent == resolved then
      return true
    end
  end
  return false
end

--- Make the path absolute, resolving any symlinks.
--- If `strict` is true and the path doesn't exist, an error is raised.
---
---@param opts { strict: boolean }|?
---
---@return obsidian.Path
Path.resolve = function(self, opts)
  opts = opts or {}

  local path, err = vim.loop.fs_realpath(vim.fn.resolve(self.filename))
  if path and not err then
    return Path.new(path)
  elseif err and opts.strict then
    error("FileNotFoundError: " .. self.filename)
  end

  -- File doesn't exist, but some parents might. Traverse up until we find a parent that
  -- does exist, and then put the path back together from there.
  local parents = self:parents()
  for _, parent in ipairs(parents) do
    path, err = vim.loop.fs_realpath(tostring(parent))
    if path and not err then
      return Path.new(path) / self:relative_to(parent)
    end
  end

  return self
end

--- Get OS stat results.
---@return table|?
Path.stat = function(self)
  local ok, resolved = pcall(function()
    return self:resolve { strict = true }
  end)
  if not ok then
    return
  end
  assert(resolved)
  local stat, _ = vim.loop.fs_stat(resolved.filename)
  return stat
end

--- Check if the path points to an existing file or directory.
---
---@return boolean
Path.exists = function(self)
  local stat = self:stat()
  return stat ~= nil
end

--- Check if the path points to an existing file.
---
---@return boolean
Path.is_file = function(self)
  local stat = self:stat()
  if stat == nil then
    return false
  else
    return stat.type == "file"
  end
end

--- Check if the path points to an existing directory.
---
---@return boolean
Path.is_dir = function(self)
  local stat = self:stat()
  if stat == nil then
    return false
  else
    return stat.type == "directory"
  end
end

--- Create a new directory at the given path.
---
---@param opts { mode: integer|?, parents: boolean|?, exist_ok: boolean|? }|?
Path.mkdir = function(self, opts)
  opts = opts or {}

  local mode = opts.mode or 448 -- 0700 -> decimal
  ---@diagnostic disable-next-line: undefined-field
  if opts.exists_ok then -- for compat with the plenary.path API.
    opts.exist_ok = true
  end

  if self:is_dir() then
    if not opts.exist_ok then
      error("FileExistsError: " .. self.filename)
    else
      return
    end
  end

  if vim.loop.fs_mkdir(self.filename, mode) then
    return
  end

  if not opts.parents then
    error("FileNotFoundError: " .. tostring(self:parent()))
  end

  local parents = self:parents()
  for i = #parents, 1, -1 do
    if not parents[i]:is_dir() then
      parents[i]:mkdir { exist_ok = true, mode = mode }
    end
  end

  self:mkdir { mode = mode }
end

Path.rmdir = function(self)
  local resolved = self:resolve { strict = false }

  if not resolved:is_dir() then
    return
  end

  local ok, err_name, err_msg = vim.loop.fs_rmdir(resolved.filename)
  if not ok then
    error(err_name .. ": " .. err_msg)
  end
end

Path.tmpdir = function()
  -- os.tmpname gives us a temporary file, but we really want a temporary directory, so we
  -- immediately delete that file.
  local tmpname = os.tmpname()
  os.remove(tmpname)
  return Path.new(tmpname)
end

return Path
