local scan = require "plenary.scandir"
local util = {}

---Check if a table (list) contains a value.
---
---@param table table
---@param val any
---@return boolean
util.contains = function(table, val)
  for i = 1, #table do
    if table[i] == val then
      return true
    end
  end
  return false
end

---Find all markdown files in a directory.
---
---@param dir string|Path
---@return string[]
util.find_markdown_files = function(dir)
  return scan.scan_dir(vim.fs.normalize(tostring(dir)), {
    hidden = false,
    add_dirs = false,
    search_pattern = ".*%.md",
  })
end

-- Characters that need shell escaping.
local UNSAFE_CHARS = "[^A-Za-z0-9_@%%+=:,./-]"

---Quote a string for safe command-line usage.
---
---Adapted from lua-shell-games.
---https://github.com/GUI/lua-shell-games/blob/master/lib/shell-games.lua
---
---@param str string
---@return string
util.quote = function(str)
  local quoted_str = tostring(str)
  if str == nil or quoted_str == nil or #quoted_str == 0 then
    return "''"
  end

  if not string.match(quoted_str, UNSAFE_CHARS) then
    return quoted_str
  end

  return "'" .. string.gsub(quoted_str, "'", "'\"'\"'") .. "'"
end

local SEARCH_CMD = "rg --no-config -S -F --json -m 1 --type md "

---Search markdown files in a directory for a given term.
---
---@param dir string|Path
---@param term string
util.search = function(dir, term)
  local norm_dir = vim.fs.normalize(tostring(dir))
  local cmd = SEARCH_CMD .. util.quote(term) .. " " .. util.quote(norm_dir)
  local handle = assert(io.popen(cmd, "r"))
  return function()
    while true do
      local line = handle:read "*l"
      if line == nil then
        return nil
      end
      local data = vim.json.decode(line)
      if data["type"] == "match" then
        return data.data.path.text
      end
    end
  end
end

---Create a new unique Zettel ID.
---
---@return string
util.zettel_id = function()
  local suffix = ""
  for _ = 1, 4 do
    suffix = suffix .. string.char(math.random(65, 90))
  end
  return tostring(os.time()) .. "-" .. suffix
end

return util
