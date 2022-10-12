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

---Quote a string for safe command-line usage.
---
---Adapted from lua-shell-games.
---https://github.com/GUI/lua-shell-games/blob/master/lib/shell-games.lua
---
---@param str string
---@return string
util.quote = function(str)
  return vim.fn.shellescape(str)
end

local char_to_hex = function(c)
  return string.format("%%%02X", string.byte(c))
end

---Encode a string into URL-safe version.
---
---@param str string
---@return string
util.urlencode = function(str)
  local url = str
  url = url:gsub("\n", "\r\n")
  url = url:gsub("([^%w _%%%-%.~])", char_to_hex)
  url = url:gsub(" ", "+")
  return url
end

util.SEARCH_CMD = { "rg", "--no-config", "--smart-case", "--fixed-strings", "--type=md" }

---@class MatchPath
---@field text string

---@class MatchText
---@field text string

---@class SubMatch
---@field match MatchText
---@field start integer
---@field end integer

---@class MatchData
---@field path MatchPath
---@field lines MatchText
---@field line_number integer
---@field absolute_offset integer
---@field submatches SubMatch[]

---Search markdown files in a directory for a given term. Return an iterator
---over `MatchData`.
---
---@param dir string|Path
---@param term string
---@param opts string|?
---@return function
util.search = function(dir, term, opts)
  local norm_dir = vim.fs.normalize(tostring(dir))
  local cmd = table.concat(util.SEARCH_CMD, " ") .. " --json "
  if opts ~= nil then
    cmd = cmd .. opts .. " "
  end
  cmd = cmd .. util.quote(term) .. " " .. util.quote(norm_dir)

  local handle = assert(io.popen(cmd, "r"))

  ---Iterator over matches.
  ---
  ---@return MatchData|?
  return function()
    while true do
      local line = handle:read "*l"
      if line == nil then
        return nil
      end
      local data = vim.json.decode(line)
      if data["type"] == "match" then
        local match_data = data.data
        return match_data
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

---Match the case of 'key' to the given 'prefix' of the key.
---
---@param prefix string
---@param key string
---@return string
util.match_case = function(prefix, key)
  local out_chars = {}
  for i = 1, string.len(key) do
    local c_key = string.sub(key, i, i)
    local c_pre = string.sub(prefix, i, i)
    if c_pre:lower() == c_key:lower() then
      table.insert(out_chars, c_pre)
    else
      table.insert(out_chars, c_key)
    end
  end
  return table.concat(out_chars, "")
end

return util
