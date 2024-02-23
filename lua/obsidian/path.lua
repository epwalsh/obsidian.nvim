local abc = require "obsidian.abc"

local is_path_obj = function(path)
  if type(path) == "table" and path.__is_obsidian_path then
    return true
  else
    return false
  end
end

local function coerce(v)
  if v == vim.NIL then
    return nil
  else
    return v
  end
end

---@param path table
---@param k string
---@param factory fun(obsidian.Path): any
local function cached_get(path, k, factory)
  local cache_key = "__" .. k
  local v = rawget(path, cache_key)
  if v == nil then
    v = factory(path)
    if v == nil then
      v = vim.NIL
    end
    path[cache_key] = v
  end
  return coerce(v)
end

---@param path obsidian.Path
---@return string|?
---@private
local function get_name(path)
  local name = vim.fs.basename(path.filename)
  if not name or string.len(name) == 0 then
    return
  else
    return name
  end
end

---@param path obsidian.Path
---@return string[]
---@private
local function get_suffixes(path)
  ---@type string[]
  local suffixes = {}
  local name = path.name
  while name and string.len(name) > 0 do
    local s, e, suffix = string.find(name, "(%.[^%.]+)$")
    if s and e and suffix then
      name = string.sub(name, 1, s - 1)
      table.insert(suffixes, suffix)
    else
      break
    end
  end

  -- reverse the list.
  ---@type string[]
  local out = {}
  for i = #suffixes, 1, -1 do
    table.insert(out, suffixes[i])
  end
  return out
end

---@param path obsidian.Path
---@return string|?
---@private
local function get_suffix(path)
  local suffixes = path.suffixes
  if #suffixes > 0 then
    return suffixes[#suffixes]
  else
    return nil
  end
end

---@param path obsidian.Path
---@return string|?
---@private
local function get_stem(path)
  local name, suffix = path.name, path.suffix
  if not name then
    return
  elseif not suffix then
    return name
  else
    return string.sub(name, 1, string.len(name) - string.len(suffix))
  end
end

--- A Path class that provides a subset of the functionality of the Python pathlib library while
--- staying true to its API. It improves on a number of bugs in plenary.path.
---
---@class obsidian.Path : obsidian.ABC
---
---@field filename string The underlying filename as a string.
---@field name string|? The final path component, if any.
---@field suffix string|? The final extension of the path, if any.
---@field suffixes string[] A list of all of the path's extensions.
---@field stem string|? The final path component, without its suffix.
local Path = abc.new_class()

Path.mt = {
  __tostring = function(self)
    return self.filename
  end,
  __eq = function(a, b)
    return a.filename == b.filename
  end,
  __div = function(self, other)
    return self:joinpath(other)
  end,
  __index = function(self, k)
    local raw = rawget(Path, k)
    if raw then
      return raw
    end

    local factory
    if k == "name" then
      factory = get_name
    elseif k == "suffix" then
      factory = get_suffix
    elseif k == "suffixes" then
      factory = get_suffixes
    elseif k == "stem" then
      factory = get_stem
    end

    if factory then
      return cached_get(self, k, factory)
    end
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

---@return string|?
---@private
Path.fs_realpath = function(self)
  local path = vim.loop.fs_realpath(vim.fn.resolve(self.filename))
  ---@cast path string|?
  return path
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

---@param ... obsidian.Path|string
---@return obsidian.Path
Path.joinpath = function(self, ...)
  local args = { ... }
  for i, v in ipairs(args) do
    args[i] = tostring(v)
  end
  return Path.new(vim.fs.joinpath(self.filename, unpack(args)))
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

  local realpath = self:fs_realpath()
  if realpath then
    return Path.new(realpath)
  elseif opts.strict then
    error("FileNotFoundError: " .. self.filename)
  end

  -- File doesn't exist, but some parents might. Traverse up until we find a parent that
  -- does exist, and then put the path back together from there.
  local parents = self:parents()
  for _, parent in ipairs(parents) do
    local parent_realpath = parent:fs_realpath()
    if parent_realpath then
      return Path.new(parent_realpath) / self:relative_to(parent)
    end
  end

  return self
end

--- Get OS stat results.
---
---@return table|?
Path.stat = function(self)
  local realpath = self:fs_realpath()
  if realpath then
    local stat, _ = vim.loop.fs_stat(realpath)
    return stat
  end
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

Path.cwd = function()
  return assert(Path.new(vim.loop.cwd()))
end

return Path
