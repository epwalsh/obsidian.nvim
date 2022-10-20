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

util.SEARCH_CMD = { "rg", "--no-config", "--fixed-strings", "--type=md" }

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
---@return string|?
util.match_case = function(prefix, key)
  local out_chars = {}
  for i = 1, string.len(key) do
    local c_key = string.sub(key, i, i)
    local c_pre = string.sub(prefix, i, i)
    if c_pre:lower() == c_key:lower() then
      table.insert(out_chars, c_pre)
    elseif c_pre:len() > 0 then
      return nil
    else
      table.insert(out_chars, c_key)
    end
  end
  return table.concat(out_chars, "")
end

---Replace references of the form '[[xxx|xxx]]', '[[xxx]]', or '[xxx](xxx)' with their title.
---
---@param s string
---@return string
util.replace_refs = function(s)
  local out, _ = string.gsub(s, "%[%[[^%|%]]+%|([^%]]+)%]%]", "%1")
  out, _ = out:gsub("%[%[([^%]]+)%]%]", "%1")
  out, _ = out:gsub("%[([^%]]+)%]%([^%)]+%)", "%1")
  return out
end

---Find refs and URLs.
---
---@param s string
---@param patterns string[]|?
---@return table
util.find_refs = function(s, patterns)
  patterns = patterns and patterns
    or {
      "%[%[[^%|%]]+%|[^%]]+%]%]", -- [[xxx|xxx]]
      "%[%[[^%]%|]+%]%]", -- [[xxx]]
      "%[[^%]]+%]%([^%)]+%)", -- [xxx](xxx)
    }

  local matches = {}

  for _, pattern in pairs(patterns) do
    local search_start = 1
    while search_start < #s do
      local m_start, m_end = string.find(s, pattern, search_start)
      if m_start ~= nil and m_end ~= nil then
        table.insert(matches, { m_start, m_end })
        search_start = m_end
      else
        break
      end
    end
  end

  table.sort(matches, function(a, b)
    return a[1] < b[1]
  end)

  return matches
end

---Find all refs and replace with their titles.
---
---@param s string
---@param patterns string[]|?
--
---@return string
---@return table
---@return string[]
util.find_and_replace_refs = function(s, patterns)
  local pieces = {}
  local refs = {}
  local is_ref = {}
  local matches = util.find_refs(s, patterns)
  local last_end = 1
  for _, match in pairs(matches) do
    local m_start, m_end = unpack(match)
    if last_end < m_start then
      table.insert(pieces, string.sub(s, last_end, m_start - 1))
      table.insert(is_ref, false)
    end
    local ref_str = string.sub(s, m_start, m_end)
    table.insert(pieces, util.replace_refs(ref_str))
    table.insert(refs, ref_str)
    table.insert(is_ref, true)
    last_end = m_end + 1
  end

  local indices = {}
  local length = 0
  for i, piece in ipairs(pieces) do
    local i_end = length + string.len(piece)
    if is_ref[i] then
      table.insert(indices, { length + 1, i_end })
    end
    length = i_end
  end

  return table.concat(pieces, ""), indices, refs
end

util.is_array = function(t)
  if type(t) ~= "table" then
    return false
  end

  --check if all the table keys are numerical and count their number
  local count = 0
  for k, _ in pairs(t) do
    if type(k) ~= "number" then
      return false
    else
      count = count + 1
    end
  end

  --all keys are numerical. now let's see if they are sequential and start with 1
  for i = 1, count do
    --Hint: the VALUE might be "nil", in that case "not t[i]" isn't enough, that's why we check the type
    if not t[i] and type(t[i]) ~= "nil" then
      return false
    end
  end
  return true
end

util.strip = function(s)
  local out = string.gsub(s, "^%s+", "")
  return out
end

util.table_length = function(x)
  local n = 0
  for _ in pairs(x) do
    n = n + 1
  end
  return n
end

-- Determines if cursor is currently inside markdown link
-- @return integer, integer
util.cursor_on_markdown_link = function()
  local current_line = vim.api.nvim_get_current_line()
  local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
  
  -- This fixes an issue where the link was unfollowable while the cursor
  -- was on the first bracket and at the beginning of the line
  local current_line_lh = current_line
  if cur_col - 2 >= 2 then
    local current_line_lh = current_line:sub(1, cur_col)
  end
  
  -- Search for two open brackets followed by any number of non-open bracket
  -- characters nor close bracket characters
  local open = current_line_lh:find("%[%[[^%[%]]*%]?%]?$") 
  local close = current_line:find("%]%]", cur_col)

  if open == nil or close == nil then
      return nil, nil
  else 
      return open, close
  end
end

return util
