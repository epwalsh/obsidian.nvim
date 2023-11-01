local util = require "obsidian.util"

---@class obsidian.yaml.Line
---@field content string
---@field raw_content string
---@field indent integer
local Line = {}

---Create a new Line instance from a raw line string.
---@param raw_line string
---@param base_indent integer|?
---@return obsidian.yaml.Line
Line.new = function(raw_line, base_indent)
  local self = setmetatable({}, { __index = Line })
  self.indent = util.count_indent(raw_line)
  if base_indent ~= nil then
    if base_indent > self.indent then
      error "relative indentation for line is less than base indentation"
    end
    self.indent = self.indent - base_indent
  end
  self.raw_content = util.lstrip_whitespace(raw_line, base_indent)
  self.content = util.strip_whitespace(self.raw_content)
  return self
end

---Check if a line is empty.
---@param self obsidian.yaml.Line
---@return boolean
Line.is_empty = function(self)
  if util.strip_comments(self.content) == "" then
    return true
  else
    return false
  end
end

return Line
