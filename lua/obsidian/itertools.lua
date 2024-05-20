local M = {}

---Create an iterator from an iterable type such as a table/array, or string.
---For mapping tables the behavior matches Python where the return iterator is over keys.
---For convenience this also accepts iterator functions, in which case it returns the original function as is.
---@param iterable table|string|function
---@return function
M.iter = function(iterable)
  if type(iterable) == "function" then
    return iterable
  elseif type(iterable) == "string" then
    local i = 1
    local n = string.len(iterable)

    return function()
      if i > n then
        return nil
      else
        local c = string.sub(iterable, i, i)
        i = i + 1
        return c
      end
    end
  elseif type(iterable) == "table" then
    if vim.tbl_isempty(iterable) then
      return function()
        return nil
      end
    elseif vim.islist(iterable) then
      local i = 1
      local n = #iterable

      return function()
        if i > n then
          return nil
        else
          local x = iterable[i]
          i = i + 1
          return x
        end
      end
    else
      return M.iter(vim.tbl_keys(iterable))
    end
  else
    error("unexpected type '" .. type(iterable) .. "'")
  end
end

---Create an enumeration iterator over an iterable.
---@param iterable table|string|function
---@return function
M.enumerate = function(iterable)
  local iterator = M.iter(iterable)
  local i = 0

  return function()
    local next = iterator()
    if next == nil then
      return nil, nil
    else
      i = i + 1
      return i, next
    end
  end
end

---Zip two iterables together.
---@param iterable1 table|string|function
---@param iterable2 table|string|function
---@return function
M.zip = function(iterable1, iterable2)
  local iterator1 = M.iter(iterable1)
  local iterator2 = M.iter(iterable2)

  return function()
    local next1 = iterator1()
    local next2 = iterator2()
    if next1 == nil or next2 == nil then
      return nil
    else
      return next1, next2
    end
  end
end

return M
