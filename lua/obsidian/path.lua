local abc = require "obsidian.abc"

---@class obsidian.Path : obsidian.ABC
---
---@field filename string
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

  ---@type string
  local filename
  if #args == 1 then
    filename = tostring(args[1])
  elseif #args == 2 then
    filename = tostring(args[2])
  end

  self.filename = vim.fs.normalize(filename)

  return self
end

--- Make the path absolute, resolving any symlinks.
---
---@return obsidian.Path
Path.resolve = function(self)
  return Path.new(vim.fs.resolve(self.filename))
end

return Path
