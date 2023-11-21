local util = require "obsidian.util"

local yaml = {}

yaml.parsers = {
  ["native"] = require "obsidian.yaml.native",
  ["yq"] = require "obsidian.yaml.yq",
}

yaml.parser = "native"

---Set the YAML parser to use.
---@param parser string
yaml.set_parser = function(parser)
  if yaml.parsers[parser] == nil then
    error("Undefined parser " .. parser)
  else
    yaml.parser = parser
  end
end

---Reset to the default parser.
yaml.reset_parser = function()
  yaml.parser = "native"
end

---Deserialize a YAML string.
---@param str string
---@return any
yaml.loads = function(str)
  return yaml.parsers[yaml.parser].loads(str)
end

---@param s string
---@return boolean
local should_quote = function(s)
  -- TODO: this probably doesn't cover all edge cases.
  -- See https://www.yaml.info/learn/quote.html
  -- Check if it starts with a special character.
  if string.match(s, [[^["'\\[{&!-].*]]) then
    return true
  -- Check if it looks like a number.
  elseif string.match(s, "^[%d.-]+$") then
    return true
  -- Check if it's an empty string.
  elseif s == "" or string.match(s, "^[%s]+$") then
    return true
  else
    return false
  end
end

---@return string[]
local dumps
dumps = function(x, indent, order)
  local indent_str = string.rep(" ", indent)

  if type(x) == "string" then
    if should_quote(x) then
      x = string.gsub(x, '"', '\\"')
      return { indent_str .. [["]] .. x .. [["]] }
    else
      return { indent_str .. x }
    end
  end

  if type(x) == "boolean" then
    return { indent_str .. tostring(x) }
  end

  if type(x) == "number" then
    return { indent_str .. tostring(x) }
  end

  if type(x) == "table" then
    local out = {}

    if util.tbl_is_array(x) then
      for _, v in ipairs(x) do
        local item_lines = dumps(v, indent + 2)
        table.insert(out, indent_str .. "- " .. util.lstrip_whitespace(item_lines[1]))
        for i = 2, #item_lines do
          table.insert(out, item_lines[i])
        end
      end
    else
      -- Gather and sort keys so we can keep the order deterministic.
      local keys = {}
      for k, _ in pairs(x) do
        table.insert(keys, k)
      end
      table.sort(keys, order)
      for _, k in ipairs(keys) do
        local v = x[k]
        if type(v) == "string" or type(v) == "boolean" or type(v) == "number" then
          table.insert(out, indent_str .. tostring(k) .. ": " .. dumps(v, 0)[1])
        elseif type(v) == "table" and vim.tbl_isempty(v) then
          table.insert(out, indent_str .. tostring(k) .. ": []")
        else
          local item_lines = dumps(v, indent + 2)
          table.insert(out, indent_str .. tostring(k) .. ":")
          for _, line in ipairs(item_lines) do
            table.insert(out, line)
          end
        end
      end
    end

    return out
  end

  error("Can't convert object with type " .. type(x) .. " to YAML")
end

---Dump an object to YAML lines.
---@param x any
---@param order function
---@return string[]
yaml.dumps_lines = function(x, order)
  return dumps(x, 0, order)
end

---Dump an object to a YAML string.
---@param x any
---@param order function|?
---@return string
yaml.dumps = function(x, order)
  return table.concat(dumps(x, 0, order), "\n")
end

return yaml
