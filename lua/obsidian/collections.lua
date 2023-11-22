local M = {}

---Like Python's default dict.
---@class DefaultTbl
local DefaultTbl = {}
M.DefaultTbl = DefaultTbl

DefaultTbl.__mt = {
  __index = function(t, k)
    if DefaultTbl[k] then
      t[k] = DefaultTbl[k]
    else
      t[k] = t.__factory()
    end
    return t[k]
  end,
  __tostring = function(self)
    local inner = self.__factory()
    if getmetatable(inner) == getmetatable(self) then
      return string.format("DefaultTbl(%s)", inner)
    else
      return string.format("DefaultTbl(%s)", vim.inspect(inner))
    end
  end,
}

---@param factory function
---@return DefaultTbl
DefaultTbl.new = function(factory)
  local self = setmetatable({}, DefaultTbl.__mt)
  self.__factory = factory
  return self
end

---Create a DefaultTbl with a factory function that returns an empty table.
---In Python, this would be equivalent to `DefaultDict(dict)`.
---@return DefaultTbl
DefaultTbl.with_tbl = function()
  return DefaultTbl.new(function()
    return {}
  end)
end

return M
