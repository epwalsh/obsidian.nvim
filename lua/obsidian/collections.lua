local abc = require "obsidian.abc"

local M = {}

---Like Python's `defaultdict`.
---@class DefaultTbl : obsidian.ABC
---@field __factory function
local DefaultTbl = abc.new_class {
  __tostring = function(self)
    local inner = self.__factory()
    if getmetatable(inner) == getmetatable(self) then
      return string.format("DefaultTbl(%s)", inner)
    else
      return string.format("DefaultTbl(%s)", vim.inspect(inner))
    end
  end,
}

DefaultTbl.mt.__index = function(self, k)
  if DefaultTbl[k] then
    self[k] = DefaultTbl[k]
  else
    self[k] = self.__factory()
  end
  return self[k]
end

M.DefaultTbl = DefaultTbl

---@param factory function
---@return DefaultTbl
DefaultTbl.new = function(factory)
  local self = DefaultTbl.init {
    __factory = factory,
  }
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

--This will only work for Lua 5.2+. Neovim currently uses Lua 5.1.
-- ---Like Python's `OrderedDict`.
-- ---@class OrderedTbl : obsidian.ABC
-- ---@field __index_to_key any[]
-- ---@field __key_to_value table
-- local OrderedTbl = abc.new_class {
--   ---@param self OrderedTbl
--   __index = function(self, k)
--     return self.__key_to_value[k]
--   end,

--   ---@param self OrderedTbl
--   __newindex = function(self, k, v)
--     self.__index_to_key[#self.__index_to_key + 1] = k
--     self.__key_to_value[k] = v
--   end,

--   ---@param self OrderedTbl
--   __pairs = function(self)
--     ---@param self_ OrderedTbl
--     ---@param idx integer|?
--     return function(self_, idx)
--       idx = idx and idx or 1
--       local key = self_.__index_to_key[idx]
--       if key ~= nil then
--         return idx + 1, self_.__key_to_value[key]
--       else
--         return nil
--       end
--     end,
--       self,
--       nil
--   end,
-- }

-- M.OrderedTbl = OrderedTbl

-- ---@return OrderedTbl
-- OrderedTbl.new = function()
--   local self = OrderedTbl.init {
--     __index_to_key = {},
--     __key_to_value = {},
--   }
--   return self
-- end

-------------------------
--- Stack implementation
-------------------------

-- Create new stack
function M.new_stack()
  return {}
end

-- Push an item onto the stack
function M.push(stack, item)
  table.insert(stack, item)
end

-- Pop an item from the stack
function M.pop(stack)
  if #stack == 0 then
    return nil
  end
  return table.remove(stack)
end

-- Check the top item on the stack
function M.peek(stack)
  if #stack == 0 then
    return nil
  end
  return stack[#stack]
end

-- Check if the stack is empty
function M.is_empty(stack)
  return #stack == 0
end

return M
