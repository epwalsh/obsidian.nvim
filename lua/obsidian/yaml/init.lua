local util = require "obsidian.util"

local yaml = {}

yaml.parsers = {
  ["native"] = require "obsidian.yaml.native",
  ["yq"] = require "obsidian.yaml.yq",
}

---@return string
local detect_parser = function()
  if vim.fn.executable "yq" then
    return "yq"
  else
    return "native"
  end
end

yaml.parser = detect_parser()

---Set the YAML parser to use.
---@param parser string
yaml.set_parser = function(parser)
  yaml.parser = parser
end

---Reset to the default parser.
yaml.reset_parser = function()
  yaml.parser = detect_parser()
end

---Deserialize a YAML string.
---@param str string
---@return any
yaml.loads = function(str)
  return yaml.parsers[yaml.parser].loads(str)
end

---@return string[]
local dumps
dumps = function(x, indent, order)
  local indent_str = string.rep(" ", indent)

  if type(x) == "string" then
    -- TODO: make this more robust
    if string.match(x, "%w") then
      return { indent_str .. x }
    else
      return { indent_str .. [["]] .. x .. [["]] }
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

    if util.is_array(x) then
      for _, v in ipairs(x) do
        local item_lines = dumps(v, indent + 2)
        table.insert(out, indent_str .. "- " .. util.strip(item_lines[1]))
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
        elseif type(v) == "table" and util.table_length(v) == 0 then
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
