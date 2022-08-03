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

return util
