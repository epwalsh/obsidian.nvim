local Line = require "obsidian.yaml.line"
local abc = require "obsidian.abc"
local util = require "obsidian.util"
local iter = require("obsidian.itertools").iter

local m = {}

---@class obsidian.yaml.ParserOpts
---@field luanil boolean
local ParserOpts = {}

m.ParserOpts = ParserOpts

---@return obsidian.yaml.ParserOpts
ParserOpts.default = function()
  return {
    luanil = true,
  }
end

---@param opts table
---@return obsidian.yaml.ParserOpts
ParserOpts.normalize = function(opts)
  ---@type obsidian.yaml.ParserOpts
  opts = vim.tbl_extend("force", ParserOpts.default(), opts)
  return opts
end

---@class obsidian.yaml.Parser : obsidian.ABC
---@field opts obsidian.yaml.ParserOpts
local Parser = abc.new_class()

m.Parser = Parser

---@enum YamlType
local YamlType = {
  Scalar = "Scalar", -- a boolean, string, number, or NULL
  Mapping = "Mapping",
  Array = "Array",
  ArrayItem = "ArrayItem",
  EmptyLine = "EmptyLine",
}

m.YamlType = YamlType

---@class vim.NIL

---Create a new Parser.
---@param opts obsidian.yaml.ParserOpts|?
---@return obsidian.yaml.Parser
m.new = function(opts)
  local self = Parser.init()
  self.opts = ParserOpts.normalize(opts and opts or {})
  return self
end

---Parse a YAML string.
---@param str string
---@return any
Parser.parse = function(self, str)
  -- Collect and pre-process lines.
  local lines = {}
  local base_indent = 0
  for raw_line in str:gmatch "[^\r\n]+" do
    local ok, result = pcall(Line.new, raw_line, base_indent)
    if ok then
      local line = result
      if #lines == 0 then
        base_indent = line.indent
        line.indent = 0
      end
      table.insert(lines, line)
    else
      local err = result
      error(self:_error_msg(tostring(err), #lines + 1))
    end
  end

  -- Now iterate over the root elements, differing to `self:_parse_next()` to recurse into child elements.
  ---@type any
  local root_value = nil
  ---@type table|?
  local parent = nil
  local current_indent = 0
  local i = 1
  while i <= #lines do
    local line = lines[i]

    if line:is_empty() then
      -- Empty line, skip it.
      i = i + 1
    elseif line.indent == current_indent then
      local value
      local value_type
      i, value, value_type = self:_parse_next(lines, i)
      assert(value_type ~= YamlType.EmptyLine)
      if root_value == nil and line.indent == 0 then
        -- Set the root value.
        if value_type == YamlType.ArrayItem then
          root_value = { value }
        else
          root_value = value
        end

        -- The parent must always be a table (array or mapping), so set that to the root value now
        -- if we have a table.
        if type(root_value) == "table" then
          parent = root_value
        end
      elseif util.tbl_is_array(parent) and value_type == YamlType.ArrayItem then
        -- Add value to parent array.
        parent[#parent + 1] = value
      elseif util.tbl_is_mapping(parent) and value_type == YamlType.Mapping then
        assert(parent ~= nil) -- for type checking
        -- Add value to parent mapping.
        for key, item in pairs(value) do
          -- Check for duplicate keys.
          if util.tbl_contains_key(parent, key) then
            error(self:_error_msg("duplicate key '" .. key .. "' found in table", i, line.content))
          else
            parent[key] = item
          end
        end
      else
        error(self:_error_msg("unexpected value", i, line.content))
      end
    else
      error(self:_error_msg("invalid indentation", i))
    end
    current_indent = line.indent
  end

  return root_value
end

---Parse the next single item, recursing to child blocks if necessary.
---@param self obsidian.yaml.Parser
---@param lines obsidian.yaml.Line[]
---@param i integer
---@param text string|?
---@return integer, any, string
Parser._parse_next = function(self, lines, i, text)
  local line = lines[i]
  if text == nil then
    -- Skip empty lines.
    while line:is_empty() and i <= #lines do
      i = i + 1
      line = lines[i]
    end
    if line:is_empty() then
      return i, nil, YamlType.EmptyLine
    end
    text = util.strip_comments(line.content)
  end

  local _, ok, value

  -- First just check for a string enclosed in quotes.
  if util.has_enclosing_chars(text) then
    _, _, value = self:_parse_string(i, text)
    return i + 1, value, YamlType.Scalar
  end

  -- Check for array item, like `- foo`.
  ok, i, value = self:_try_parse_array_item(lines, i, text)
  if ok then
    return i, value, YamlType.ArrayItem
  end

  -- Check for a block string field, like `foo: |`.
  ok, i, value = self:_try_parse_block_string(lines, i, text)
  if ok then
    return i, value, YamlType.Mapping
  end

  -- Check for any other `key: value` fields.
  ok, i, value = self:_try_parse_field(lines, i, text)
  if ok then
    return i, value, YamlType.Mapping
  end

  -- Otherwise we have an inline value.
  local value_type
  value, value_type = self:_parse_inline_value(i, text)
  return i + 1, value, value_type
end

---@return vim.NIL|nil
Parser._new_null = function(self)
  if self.opts.luanil then
    return nil
  else
    return vim.NIL
  end
end

---@param self obsidian.yaml.Parser
---@param msg string
---@param line_num integer
---@param line_text string|?
---@return string
---@diagnostic disable-next-line: unused-local
Parser._error_msg = function(self, msg, line_num, line_text)
  local full_msg = "[line=" .. tostring(line_num) .. "] " .. msg
  if line_text ~= nil then
    full_msg = full_msg .. " (text='" .. line_text .. "')"
  end
  return full_msg
end

---@param self obsidian.yaml.Parser
---@param i integer
---@param lines obsidian.yaml.Line[]
---@param text string|?
---@return boolean, integer, any
Parser._try_parse_field = function(self, lines, i, text)
  local line = lines[i]
  text = text and text or util.strip_comments(line.content)

  local _, key, value

  -- First look for start of mapping, array, block, etc, e.g. 'foo:'
  _, _, key = string.find(text, "([a-zA-Z0-9_-]+[a-zA-Z0-9_ -]*):$")
  if not key then
    -- Then try inline field, e.g. 'foo: bar'
    _, _, key, value = string.find(text, "([a-zA-Z0-9_-]+[a-zA-Z0-9_ -]*): (.*)")
  end

  value = value and util.strip_whitespace(value) or nil
  if value == "" then
    value = nil
  end

  if key ~= nil and value ~= nil then
    -- This is a mapping, e.g. `foo: 1`.
    local out = {}
    value = self:_parse_inline_value(i, value)
    local j = i + 1
    -- Check for multi-line string here.
    local next_line = lines[j]
    if type(value) == "string" and next_line ~= nil and next_line.indent > line.indent then
      local next_indent = next_line.indent
      while next_line ~= nil and next_line.indent == next_indent do
        local next_value_str = util.strip_comments(next_line.content)
        if string.len(next_value_str) > 0 then
          local next_value = self:_parse_inline_value(j, next_line.content)
          if type(next_value) ~= "string" then
            error(self:_error_msg("expected a string, found " .. type(next_value), j, next_line.content))
          end
          value = value .. " " .. next_value
        end
        j = j + 1
        next_line = lines[j]
      end
    end
    out[key] = value
    return true, j, out
  elseif key ~= nil then
    local out = {}
    local next_line = lines[i + 1]
    local j = i + 1
    if next_line ~= nil and next_line.indent >= line.indent and vim.startswith(next_line.content, "- ") then
      -- This is the start of an array.
      local array
      j, array = self:_parse_array(lines, j)
      out[key] = array
    elseif next_line ~= nil and next_line.indent > line.indent then
      -- This is the start of a mapping.
      local mapping
      j, mapping = self:_parse_mapping(j, lines)
      out[key] = mapping
    else
      -- This is an implicit null field.
      out[key] = self:_new_null()
    end
    return true, j, out
  else
    return false, i, nil
  end
end

---@param self obsidian.yaml.Parser
---@param i integer
---@param lines obsidian.yaml.Line[]
---@param text string|?
---@return boolean, integer, any
Parser._try_parse_block_string = function(self, lines, i, text)
  local line = lines[i]
  text = text and text or util.strip_comments(line.content)
  local _, _, block_key = string.find(text, "([a-zA-Z0-9_-]+):%s?|")
  if block_key ~= nil then
    local block_lines = {}
    local j = i + 1
    local next_line = lines[j]
    if next_line == nil then
      error(self:_error_msg("expected another line", i, text))
    end
    local item_indent = next_line.indent
    while j <= #lines do
      next_line = lines[j]
      if next_line ~= nil and next_line.indent >= item_indent then
        j = j + 1
        table.insert(block_lines, util.lstrip_whitespace(next_line.raw_content, item_indent))
      else
        break
      end
    end
    local out = {}
    out[block_key] = table.concat(block_lines, "\n")
    return true, j, out
  else
    return false, i, nil
  end
end

---@param self obsidian.yaml.Parser
---@param i integer
---@param lines obsidian.yaml.Line[]
---@param text string|?
---@return boolean, integer, any
Parser._try_parse_array_item = function(self, lines, i, text)
  local line = lines[i]
  text = text and text or util.strip_comments(line.content)
  if vim.startswith(text, "- ") then
    local _, _, array_item_str = string.find(text, "- (.*)")
    local value
    -- Check for null entry.
    if array_item_str == "" then
      value = self:_new_null()
      i = i + 1
    else
      i, value = self:_parse_next(lines, i, array_item_str)
    end
    return true, i, value
  else
    return false, i, nil
  end
end

---@param self obsidian.yaml.Parser
---@param lines obsidian.yaml.Line[]
---@param i integer
---@return integer, any[]
Parser._parse_array = function(self, lines, i)
  local out = {}
  local item_indent = lines[i].indent
  while i <= #lines do
    local line = lines[i]
    if line.indent == item_indent and vim.startswith(line.content, "- ") then
      local is_array_item, value
      is_array_item, i, value = self:_try_parse_array_item(lines, i)
      assert(is_array_item)
      out[#out + 1] = value
    elseif line:is_empty() then
      i = i + 1
    else
      break
    end
  end
  if vim.tbl_isempty(out) then
    error(self:_error_msg("tried to parse an array but didn't find any entries", i))
  end
  return i, out
end

---@param self obsidian.yaml.Parser
---@param i integer
---@param lines obsidian.yaml.Line[]
---@return integer, table
Parser._parse_mapping = function(self, i, lines)
  local out = {}
  local item_indent = lines[i].indent
  while i <= #lines do
    local line = lines[i]
    if line.indent == item_indent then
      local value, value_type
      i, value, value_type = self:_parse_next(lines, i)
      if value_type == YamlType.Mapping then
        for key, item in pairs(value) do
          -- Check for duplicate keys.
          if util.tbl_contains_key(out, key) then
            error(self:_error_msg("duplicate key '" .. key .. "' found in table", i))
          else
            out[key] = item
          end
        end
      else
        error(self:_error_msg("unexpected value found found in table", i))
      end
    else
      break
    end
  end
  if vim.tbl_isempty(out) then
    error(self:_error_msg("tried to parse a mapping but didn't find any entries to parse", i))
  end
  return i, out
end

---@param self obsidian.yaml.Parser
---@param i integer
---@param text string
---@return any, string
Parser._parse_inline_value = function(self, i, text)
  for parse_func_and_type in iter {
    { self._parse_number, YamlType.Scalar },
    { self._parse_null, YamlType.Scalar },
    { self._parse_boolean, YamlType.Scalar },
    { self._parse_inline_array, YamlType.Array },
    { self._parse_inline_mapping, YamlType.Mapping },
    { self._parse_string, YamlType.Scalar },
  } do
    local parse_func, parse_type = unpack(parse_func_and_type)
    local ok, errmsg, res = parse_func(self, i, text)
    if ok then
      return res, parse_type
    elseif errmsg ~= nil then
      error(errmsg)
    end
  end
  -- Should never get here because we always fall back to parsing as a string.
  error(self:_error_msg("unable to parse", i))
end

---@param self obsidian.yaml.Parser
---@param i integer
---@param text string
---@return boolean, string|?, any[]|?
Parser._parse_inline_array = function(self, i, text)
  local str
  if vim.startswith(text, "[") then
    str = string.sub(text, 2)
  else
    return false, nil, nil
  end

  if vim.endswith(str, "]") then
    str = string.sub(str, 1, -2)
  else
    return false, nil, nil
  end

  local out = {}
  while string.len(str) > 0 do
    local item_str
    if vim.startswith(str, "[") then
      -- Nested inline array.
      item_str, str = util.next_item(str, { "]" }, true)
    elseif vim.startswith(str, "{") then
      -- Nested inline mapping.
      item_str, str = util.next_item(str, { "}" }, true)
    else
      -- Regular item.
      item_str, str = util.next_item(str, { "," }, false)
    end
    if item_str == nil then
      return false, self:_error_msg("invalid inline array", i, text), nil
    end
    out[#out + 1] = self:_parse_inline_value(i, item_str)

    if vim.startswith(str, ",") then
      str = string.sub(str, 2)
    end
    str = util.lstrip_whitespace(str)
  end

  return true, nil, out
end

---@param self obsidian.yaml.Parser
---@param i integer
---@param text string
---@return boolean, string|?, table|?
Parser._parse_inline_mapping = function(self, i, text)
  local str
  if vim.startswith(text, "{") then
    str = string.sub(text, 2)
  else
    return false, nil, nil
  end

  if vim.endswith(str, "}") then
    str = string.sub(str, 1, -2)
  else
    return false, self:_error_msg("invalid inline mapping", i, text), nil
  end

  local out = {}
  while string.len(str) > 0 do
    -- Parse the key.
    local key_str
    key_str, str = util.next_item(str, { ":" }, false)
    if key_str == nil then
      return false, self:_error_msg("invalid inline mapping", i, text), nil
    end
    local _, _, key = self:_parse_string(i, key_str)

    -- Parse the value.
    str = util.lstrip_whitespace(str)
    local value_str
    if vim.startswith(str, "[") then
      -- Nested inline array.
      value_str, str = util.next_item(str, { "]" }, true)
    elseif vim.startswith(str, "{") then
      -- Nested inline mapping.
      value_str, str = util.next_item(str, { "}" }, true)
    else
      -- Regular item.
      value_str, str = util.next_item(str, { "," }, false)
    end
    if value_str == nil then
      return false, self:_error_msg("invalid inline mapping", i, text), nil
    end
    local value = self:_parse_inline_value(i, value_str)
    if not util.tbl_contains_key(out, key) then
      out[key] = value
    else
      return false, self:_error_msg("duplicate key '" .. key .. "' found in inline mapping", i, text), nil
    end

    if vim.startswith(str, ",") then
      str = util.lstrip_whitespace(string.sub(str, 2))
    end
  end

  return true, nil, out
end

---@param self obsidian.yaml.Parser
---@param i integer
---@param text string
---@return boolean, string|?, string
---@diagnostic disable-next-line: unused-local
Parser._parse_string = function(self, i, text)
  if vim.startswith(text, [["]]) and vim.endswith(text, [["]]) then
    -- when the text is enclosed with double-quotes we need to un-escape certain characters.
    text = util.string_replace(text, [[\"]], [["]])
  end
  return true, nil, util.strip_enclosing_chars(util.strip_whitespace(text))
end

---Parse a string value.
---@param self obsidian.yaml.Parser
---@param text string
---@return string
Parser.parse_string = function(self, text)
  local _, _, str = self:_parse_string(1, util.strip_comments(text))
  return str
end

---@param self obsidian.yaml.Parser
---@param i integer
---@param text string
---@return boolean, string|?, number|?
---@diagnostic disable-next-line: unused-local
Parser._parse_number = function(self, i, text)
  local out = tonumber(text)
  if out == nil or util.isNan(out) then
    return false, nil, nil
  else
    return true, nil, out
  end
end

---Parse a number value.
---@param self obsidian.yaml.Parser
---@param text string
---@return number
Parser.parse_number = function(self, text)
  local ok, errmsg, res = self:_parse_number(1, util.strip_whitespace(util.strip_comments(text)))
  if not ok then
    errmsg = errmsg and errmsg or self:_error_msg("failed to parse a number", 1, text)
    error(errmsg)
  else
    assert(res ~= nil)
    return res
  end
end

---@param self obsidian.yaml.Parser
---@param i integer
---@param text string
---@return boolean, string|?, boolean|?
---@diagnostic disable-next-line: unused-local
Parser._parse_boolean = function(self, i, text)
  if text == "true" then
    return true, nil, true
  elseif text == "false" then
    return true, nil, false
  else
    return false, nil, nil
  end
end

---Parse a boolean value.
---@param self obsidian.yaml.Parser
---@param text string
---@return boolean
Parser.parse_boolean = function(self, text)
  local ok, errmsg, res = self:_parse_boolean(1, util.strip_whitespace(util.strip_comments(text)))
  if not ok then
    errmsg = errmsg and errmsg or self:_error_msg("failed to parse a boolean", 1, text)
    error(errmsg)
  else
    assert(res ~= nil)
    return res
  end
end

---@param self obsidian.yaml.Parser
---@param text string
---@return boolean, string|?, vim.NIL|nil
---@diagnostic disable-next-line: unused-local
Parser._parse_null = function(self, i, text)
  if text == "null" or text == "" then
    return true, nil, self:_new_null()
  else
    return false, nil, nil
  end
end

---Parse a NULL value.
---@param self obsidian.yaml.Parser
---@param text string
---@return vim.NIL|nil
Parser.parse_null = function(self, text)
  local ok, errmsg, res = self:_parse_null(1, util.strip_whitespace(util.strip_comments(text)))
  if not ok then
    errmsg = errmsg and errmsg or self:_error_msg("failed to parse a null value", 1, text)
    error(errmsg)
  else
    return res
  end
end

---Deserialize a YAML string.
m.loads = function(str)
  local parser = m.new()
  return parser:parse(str)
end

return m
