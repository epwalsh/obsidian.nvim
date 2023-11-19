local M = {}

---Like Python's default dict.
---@class DefaultTbl
local DefaultTbl = {}
M.DefaultTbl = DefaultTbl

---@param factory function
---@return DefaultTbl
DefaultTbl.new = function(factory)
  local self = setmetatable({}, {
    __index = function(t, k)
      if DefaultTbl[k] then
        t[k] = DefaultTbl[k]
      else
        t[k] = factory()
      end
      return t[k]
    end,
  })
  return self
end

return M
