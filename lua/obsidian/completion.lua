local completion = {}

---Backtrack through a string to find the first occurence of '[['.
---
---@param input string
---@return string|?
completion._find_search_start = function(input)
  for i = string.len(input), 1, -1 do
    local substr = string.sub(input, i)
    if vim.endswith(substr, "]") then
      return nil
    elseif vim.startswith(substr, "[[") then
      return substr
    end
  end
  return nil
end

---Check if a completion request can/should be carried out. Returns a boolean
---and, if true, the search string and the column indices of where the completion
---items should be inserted.
---
---@return boolean
---@return string|?
---@return integer|?
---@return integer|?
completion.can_complete = function(request)
  local input = completion._find_search_start(request.context.cursor_before_line)
  if input == nil then
    return false, nil, nil, nil
  end

  local suffix = string.sub(request.context.cursor_after_line, 1, 2)
  local search = string.sub(input, 3)

  if string.len(search) > 0 and vim.startswith(input, "[[") then
    local cursor_col = request.context.cursor.col
    local insert_end_offset = suffix == "]]" and 1 or -1
    return true, search, cursor_col - 1 - #input, cursor_col + insert_end_offset
  else
    return false, nil, nil, nil
  end
end

completion.get_trigger_characters = function()
  return { "[" }
end

completion.get_keyword_pattern = function()
  -- See ':help pattern'
  -- Note that the enclosing [=[ ... ]=] is just a way to mark the boundary of a
  -- string in Lua.
  return [=[\%(\s\|^\)\zs\[\{2}[^\]]\+\]\{,2}]=]
end

return completion
