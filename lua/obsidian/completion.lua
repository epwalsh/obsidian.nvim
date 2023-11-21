local completion = {
  refs = {},
  tags = {},
}

---@enum obsidian.completion.RefType
completion.refs.RefType = {
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
---@return boolean, string|?, integer|?, integer|?, obsidian.completion.RefType|?
completion.refs.can_complete = function(request)
  local input, search = find_search_start(request.context.cursor_before_line)
  if input == nil or search == nil then
    return false
  elseif string.len(search) == 0 then
    return false
  end

  local suffix = string.sub(request.context.cursor_after_line, 1, 2)

  if vim.startswith(input, "[[") then
    local cursor_col = request.context.cursor.col
    local insert_end_offset = suffix == "]]" and 1 or -1
    return true, search, cursor_col - 1 - #input, cursor_col + insert_end_offset, completion.refs.RefType.Wiki
  elseif vim.startswith(input, "[") then
    local cursor_col = request.context.cursor.col
    local insert_end_offset = suffix == "]" and 1 or -1
    return true, search, cursor_col - 1 - #input, cursor_col + insert_end_offset, completion.refs.RefType.Markdown
  else
    return false
  end
end

completion.refs.get_trigger_characters = function()
  return { "[" }
end

completion.refs.get_keyword_pattern = function()
  -- Note that this is a vim pattern, not a Lua pattern. See ':help pattern'.
  -- The enclosing [=[ ... ]=] is just a way to mark the boundary of a
  -- string in Lua.
  return [=[\%(^\|[^\[]\)\zs\[\{,2}[^\]]\+\]\{,2}]=]
end

local find_tags_start = function(input)
  for i = string.len(input), 1, -1 do
    local substr = string.sub(input, i)
    if vim.startswith(substr, "#") then
      return substr, string.sub(substr, 2)
    end
  end
  return nil
end

---Find the boundaries of the YAML frontmatter within the buffer.
---@param bufnr integer
---@return integer|?, integer|?
local get_frontmatter_boundaries = function(bufnr)
  local frontmatter_start, frontmatter_end
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
  for i, line in ipairs(lines) do
    if string.match(line, "^---$") then
      if frontmatter_start then
        frontmatter_end = i
      else
        frontmatter_start = i
      end
    elseif string.match(line, [[^[^\s]+$]]) and not frontmatter_start then
      break
    end
  end
  return frontmatter_start, frontmatter_end
end

---@return boolean, string|?, boolean|?
completion.tags.can_complete = function(request)
  local input, search = find_tags_start(request.context.cursor_before_line)
  if input == nil or search == nil then
    return false
  elseif string.len(search) == 0 then
    return false
  end

  if vim.startswith(input, "#") then
    -- Check if we're inside frontmatter.
    local in_frontmatter = false
    local line = request.context.cursor.line
    local frontmatter_start, frontmatter_end = get_frontmatter_boundaries(request.context.bufnr)
    if
      frontmatter_start ~= nil
      and frontmatter_start <= line
      and frontmatter_end ~= nil
      and line <= frontmatter_end
    then
      in_frontmatter = true
    end

    return true, search, in_frontmatter
  else
    return false
  end
end

completion.tags.get_trigger_characters = function()
  return { "#" }
end

completion.tags.get_keyword_pattern = function()
  -- Note that this is a vim pattern, not a Lua pattern. See ':help pattern'.
  -- The enclosing [=[ ... ]=] is just a way to mark the boundary of a
  -- string in Lua.
  -- return [=[\%(^\|[^#]\)\zs#[a-zA-Z0-9_/-]\+]=]
  return "#[a-zA-Z0-9_/-]\\+"
end

return completion
