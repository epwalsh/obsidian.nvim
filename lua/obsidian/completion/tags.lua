local M = {}

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
M.can_complete = function(request)
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

M.get_trigger_characters = function()
  return { "#" }
end

M.get_keyword_pattern = function()
  -- Note that this is a vim pattern, not a Lua pattern. See ':help pattern'.
  -- The enclosing [=[ ... ]=] is just a way to mark the boundary of a
  -- string in Lua.
  -- return [=[\%(^\|[^#]\)\zs#[a-zA-Z0-9_/-]\+]=]
  return "#[a-zA-Z0-9_/-]\\+"
end

return M
