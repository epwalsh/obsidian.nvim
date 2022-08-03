local util = {}

---Check if a table (list) contains a value.
---
---@param table table
---@param val any
---@return boolean
util.contains = function(table, val)
  for i = 1, #table do
    if table[i] == val then
      return true
    end
  end
  return false
end

return util
