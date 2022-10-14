local _yaml = require "yaml"
local util = require "obsidian.util"

local yaml = {}

---Deserialize a YAML string.
yaml.loads = _yaml.eval

local should_quote = function(s)
  local found = string.find(s, [[']], 1, true)
  return found ~= nil
end

---@return string[]
local dumps
dumps = function(x, indent, order)
  local indent_str = string.rep(" ", indent)

  if type(x) == "string" then
    if should_quote(x) then
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
          for _, line in pairs(item_lines) do
            table.insert(out, line)
          end
        end
      end
    end

    return out
  end

  error("Can't convert object with type " .. type(x) .. " to YAML")
end

yaml.dumps_lines = function(x)
  return dumps(x, 0)
end

yaml.dumps = function(x)
  return table.concat(dumps(x, 0), "\n")
end

return yaml
