local Note = require "obsidian.note"
local Patterns = require("obsidian.search").Patterns

local M = {}

---@type { pattern: string, offset: integer }[]
local TAG_PATTERNS = {
  { pattern = "[%s%(]#" .. Patterns.TagCharsOptional .. "$", offset = 2 },
  { pattern = "^#" .. Patterns.TagCharsOptional .. "$", offset = 1 },
}

M.find_tags_start = function(input)
  for _, pattern in ipairs(TAG_PATTERNS) do
    local match = string.match(input, pattern.pattern)
    if match then
      return string.sub(match, pattern.offset + 1)
    end
  end
end

--- Find the boundaries of the YAML frontmatter within the buffer.
---@param bufnr integer
---@return integer|?, integer|?
local get_frontmatter_boundaries = function(bufnr)
  local note = Note.from_buffer(bufnr)
  if note.frontmatter_end_line ~= nil then
    return 1, note.frontmatter_end_line
  end
end

---@return boolean, string|?, boolean|?
M.can_complete = function(request)
  local search = M.find_tags_start(request.context.cursor_before_line)
  if not search or string.len(search) == 0 then
    return false
  end

  -- Check if we're inside frontmatter.
  local in_frontmatter = false
  local line = request.context.cursor.line
  local frontmatter_start, frontmatter_end = get_frontmatter_boundaries(request.context.bufnr)
  if
    frontmatter_start ~= nil
    and frontmatter_start <= (line + 1)
    and frontmatter_end ~= nil
    and (line + 1) <= frontmatter_end
  then
    in_frontmatter = true
  end

  return true, search, in_frontmatter
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
