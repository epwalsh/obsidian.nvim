local completion = {}

---@enum obsidian.completion.RefType
completion.RefType = {
  Wiki = 1,
  Markdown = 2,
}

---Backtrack through a string to find the first occurrence of '[['.
---
---@param input string
---@return string|?, string|?, obsidian.completion.RefType|?
completion._find_search_start = function(input)
  for i = string.len(input), 1, -1 do
    local substr = string.sub(input, i)
    if vim.startswith(substr, "]") or vim.endswith(substr, "]") then
      return nil
    elseif vim.startswith(substr, "[[") then
      return substr, string.sub(substr, 3)
    elseif vim.startswith(substr, "[") and string.sub(substr, i - 1, i - 1) ~= "[" then
      return substr, string.sub(substr, 2)
    end
  end
  return nil
end

---Check if a completion request can/should be carried out. Returns a boolean
---and, if true, the search string and the column indices of where the completion
---items should be inserted.
---
---@return boolean
---@return string|?, integer|?, integer|?, obsidian.completion.RefType|?
completion.can_complete = function(request)
  local input, search = completion._find_search_start(request.context.cursor_before_line)
  if input == nil or search == nil then
    return false
  elseif string.len(search) == 0 then
    return false
  end

  local suffix = string.sub(request.context.cursor_after_line, 1, 2)

  if vim.startswith(input, "[[") then
    local cursor_col = request.context.cursor.col
    local insert_end_offset = suffix == "]]" and 1 or -1
    return true, search, cursor_col - 1 - #input, cursor_col + insert_end_offset, completion.RefType.Wiki
  elseif vim.startswith(input, "[") then
    local cursor_col = request.context.cursor.col
    local insert_end_offset = suffix == "]" and 1 or -1
    return true, search, cursor_col - 1 - #input, cursor_col + insert_end_offset, completion.RefType.Markdown
  else
    return false
  end
end

completion.get_trigger_characters = function()
  return { "[" }
end

completion.get_keyword_pattern = function()
  -- Note that this is a vim pattern, not a Lua pattern. See ':help pattern'.
  -- The enclosing [=[ ... ]=] is just a way to mark the boundary of a
  -- string in Lua.
  return [=[\%(^\|[^\[]\)\zs\[\{,2}[^\]]\+\]\{,2}]=]
end

return completion
