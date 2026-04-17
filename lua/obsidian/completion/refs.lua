local util = require "obsidian.util"

local M = {}

---@enum obsidian.completion.RefType
M.RefType = {
  Wiki = 1,
  Markdown = 2,
}

---Backtrack through a string to find the first occurrence of '[['.
---
---@param input string
---@return string|?, string|?, obsidian.completion.RefType|?
local find_search_start = function(input)
  for i = string.len(input), 1, -1 do
    local substr = string.sub(input, i)
    if vim.startswith(substr, "]") or vim.endswith(substr, "]") then
      return nil
    elseif vim.startswith(substr, "[[") then
      return substr, string.sub(substr, 3)
    elseif vim.startswith(substr, "[") and string.sub(input, i - 1, i - 1) ~= "[" then
      return substr, string.sub(substr, 2)
    end
  end
  return nil
end

---Count the number of non-Latin characters in a string
---
---@param str string
---@return integer
local function count_non_latin_chars(str)
  local count = 0
  for uchar in str:gmatch "[%z\1-\127\194-\244][\128-\191]*" do
    -- Check that the character is not in the Latin alphabet (A-Z, a-z) and is not an ASCII character
    if not uchar:match "^[A-Za-z0-9%s%p]$" then
      count = count + 1
    end
  end
  return count
end

---Check if a completion request can/should be carried out. Returns a boolean
---and, if true, the search string and the column indices of where the completion
---items should be inserted.
---
---@return boolean, string|?, integer|?, integer|?, obsidian.completion.RefType|?
M.can_complete = function(request)
  local input, search = find_search_start(request.context.cursor_before_line)
  if input == nil or search == nil then
    return false
  elseif string.len(search) == 0 or util.is_whitespace(search) then
    return false
  end

  local start_col = nil
  local end_col = nil
  local ref_type = nil
  local cursor_col = request.context.cursor.col

  if vim.startswith(input, "[[") then
    local suffix = string.sub(request.context.cursor_after_line, 1, 2)
    local insert_end_offset = suffix == "]]" and 1 or -1
    start_col = cursor_col - 1 - #input
    end_col = cursor_col + insert_end_offset
    ref_type = M.RefType.Wiki
  elseif vim.startswith(input, "[") then
    local suffix = string.sub(request.context.cursor_after_line, 1, 1)
    local insert_end_offset = suffix == "]" and 0 or -1
    start_col = cursor_col - 1 - #input
    end_col = cursor_col + insert_end_offset
    ref_type = M.RefType.Markdown
  else
    return false
  end

  -- Adjust the column indices to account for non-Latin and non-ASCII characters
  local non_latin_chars = count_non_latin_chars(request.context.cursor_before_line)
  start_col = start_col - non_latin_chars
  end_col = end_col - non_latin_chars

  return true, search, start_col, end_col, ref_type
end

M.get_trigger_characters = function()
  return { "[" }
end

M.get_keyword_pattern = function()
  -- Note that this is a vim pattern, not a Lua pattern. See ':help pattern'.
  -- The enclosing [=[ ... ]=] is just a way to mark the boundary of a
  -- string in Lua.
  return [=[\%(^\|[^\[]\)\zs\[\{1,2}[^\]]\+\]\{,2}]=]
end

return M
