local Path = require "plenary.path"
local iter = require("obsidian.itertools").iter
local log = require "obsidian.log"

local util = {}

-------------------
-- Table methods --
-------------------

---Check if a list table contains a value.
---
---@param table any[]
---@param val any
---@return boolean
util.tbl_contains = function(table, val)
  for i = 1, #table do
    if table[i] == val then
      return true
    end
  end
  return false
end

---Check if a table contains a key.
---
---@param table table
---@param needle any
---@return boolean
util.tbl_contains_key = function(table, needle)
  for key, _ in pairs(table) do
    if key == needle then
      return true
    end
  end
  return false
end

---Check if an object is an array-like table.
---@param t any
---@return boolean
util.tbl_is_array = function(t)
  if type(t) ~= "table" then
    return false
  end

  return vim.tbl_islist(t)
end

---Check if an object is an non-array table.
---@param t any
---@return boolean
util.tbl_is_mapping = function(t)
  return type(t) == "table" and (vim.tbl_isempty(t) or not util.tbl_is_array(t))
end

---Return a new list table with only the unique values of the original table.
---
---@param table table
---@return any[]
util.tbl_unique = function(table)
  local out = {}
  for _, val in pairs(table) do
    if not util.tbl_contains(out, val) then
      out[#out + 1] = val
    end
  end
  return out
end

--------------------
-- String methods --
--------------------

---Iterate over all matches of 'pattern' in 's'. 'gfind' is to 'find' as 'gsub' is to 'sub'.
---@param s string
---@param pattern string
---@param init integer|?
---@param plain boolean|?
util.gfind = function(s, pattern, init, plain)
  init = init and init or 1

  return function()
    if init < #s then
      local m_start, m_end = string.find(s, pattern, init, plain)
      if m_start ~= nil and m_end ~= nil then
        init = m_end + 1
        return m_start, m_end
      end
    end
    return nil
  end
end

---Quote a string for safe command-line usage.
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

  -- Spaces in URLs are always safely encoded with `%20`, but not always safe
  -- with `+`. For example, `+` in a query param's value will be interpreted
  -- as a literal plus-sign if the decoder is using JavaScript's `decodeURI`
  -- function.
  url = url:gsub(" ", "%%20")
  return url
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

util.escape_magic_characters = function(text)
  return text:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

---Check if a string is a valid URL.
---@param s string
---@return boolean
util.is_url = function(s)
  local search = require "obsidian.search"

  if string.match(util.strip_whitespace(s), "^" .. search.Patterns[search.RefTypes.NakedUrl] .. "$") then
    return true
  else
    return false
  end
end

-- This function removes a single backslash within double square brackets
util.unescape_single_backslash = function(text)
  return text:gsub("(%[%[[^\\]+)\\(%|[^\\]+]])", "%1%2")
end

util.string_enclosing_chars = { [["]], [[']] }

---Count the indentation of a line.
---@param str string
---@return integer
util.count_indent = function(str)
  local indent = 0
  for i = 1, #str do
    local c = string.sub(str, i, i)
    -- space or tab both count as 1 indent
    if c == " " or c == "	" then
      indent = indent + 1
    else
      break
    end
  end
  return indent
end

---Check if a string is only whitespace.
---@param str string
---@return boolean
util.is_whitespace = function(str)
  return string.match(str, "^%s+$") ~= nil
end

---Get the substring of `str` starting from the first character and up to the stop character,
---ignoring any enclosing characters (like double quotes) and stop characters that are within the
---enclosing characters. For example, if `str = [=["foo", "bar"]=]` and `stop_char = ","`, this
---would return the string `[=[foo]=]`.
---
---@param str string
---@param stop_chars string[]
---@param keep_stop_char boolean|?
---@return string|?, string
util.next_item = function(str, stop_chars, keep_stop_char)
  local og_str = str

  -- Check for enclosing characters.
  local enclosing_char = nil
  local first_char = string.sub(str, 1, 1)
  for _, c in ipairs(util.string_enclosing_chars) do
    if first_char == c then
      enclosing_char = c
      str = string.sub(str, 2)
      break
    end
  end

  local result
  local hits

  for _, stop_char in ipairs(stop_chars) do
    -- First check for next item when `stop_char` is present.
    if enclosing_char ~= nil then
      result, hits = string.gsub(
        str,
        "([^" .. enclosing_char .. "]+)([^\\]?)" .. enclosing_char .. "%s*" .. stop_char .. ".*",
        "%1%2"
      )
      result = enclosing_char .. result .. enclosing_char
    else
      result, hits = string.gsub(str, "([^" .. stop_char .. "]+)" .. stop_char .. ".*", "%1")
    end
    if hits ~= 0 then
      local i = string.find(str, stop_char, string.len(result), true)
      if keep_stop_char then
        return result .. stop_char, string.sub(str, i + 1)
      else
        return result, string.sub(str, i + 1)
      end
    end

    -- Now check for next item without the `stop_char` after.
    if not keep_stop_char and enclosing_char ~= nil then
      result, hits = string.gsub(str, "([^" .. enclosing_char .. "]+)([^\\]?)" .. enclosing_char .. "%s*$", "%1%2")
      result = enclosing_char .. result .. enclosing_char
    elseif not keep_stop_char then
      result = str
      hits = 1
    else
      result = nil
      hits = 0
    end
    if hits ~= 0 then
      if keep_stop_char then
        result = result .. stop_char
      end
      return result, ""
    end
  end

  return nil, og_str
end

---Strip whitespace from the ends of a string.
---@param str string
---@return string
util.strip_whitespace = function(str)
  return util.rstrip_whitespace(util.lstrip_whitespace(str))
end

---Strip whitespace from the right end of a string.
---@param str string
---@return string
util.rstrip_whitespace = function(str)
  str = string.gsub(str, "%s+$", "")
  return str
end

---Strip whitespace from the left end of a string.
---@param str string
---@param limit integer|?
---@return string
util.lstrip_whitespace = function(str, limit)
  if limit ~= nil then
    local num_found = 0
    while num_found < limit do
      str = string.gsub(str, "^%s", "")
      num_found = num_found + 1
    end
  else
    str = string.gsub(str, "^%s+", "")
  end
  return str
end

---Strip enclosing characters like quotes from a string.
---@param str string
---@return string
util.strip_enclosing_chars = function(str)
  local c_start = string.sub(str, 1, 1)
  local c_end = string.sub(str, #str, #str)
  for _, enclosing_char in ipairs(util.string_enclosing_chars) do
    if c_start == enclosing_char and c_end == enclosing_char then
      str = string.sub(str, 2, #str - 1)
      break
    end
  end
  return str
end

---Check if a string has enclosing characters like quotes.
---@param str string
---@return boolean
util.has_enclosing_chars = function(str)
  for _, enclosing_char in ipairs(util.string_enclosing_chars) do
    if vim.startswith(str, enclosing_char) and vim.endswith(str, enclosing_char) then
      return true
    end
  end
  return false
end

---Strip YAML comments from a string.
---@param str string
---@return string
util.strip_comments = function(str)
  if not util.has_enclosing_chars(str) then
    for i = 1, #str do
      -- TODO: handle case where '#' is escaped
      local c = string.sub(str, i, i)
      if c == "#" then
        str = util.rstrip_whitespace(string.sub(str, 1, i - 1))
        break
      end
    end
  end
  return str
end

---Check if a string contains a substring.
---@param str string
---@param substr string
---@return boolean
util.string_contains = function(str, substr)
  local i = string.find(str, substr, 1, true)
  return i ~= nil
end

---Replace up to `n` occurrences of `what` in `s` with `with`.
---@param s string
---@param what string
---@param with string
---@param n integer|?
---@return string
---@return integer
util.string_replace = function(s, what, with, n)
  local count = 0

  local function replace(s_)
    if n ~= nil and count >= n then
      return s_
    end

    local b_idx, e_idx = string.find(s_, what, 1, true)
    if b_idx == nil or e_idx == nil then
      return s_
    end

    count = count + 1
    return string.sub(s_, 1, b_idx - 1) .. with .. replace(string.sub(s_, e_idx + 1))
  end

  s = replace(s)
  return s, count
end

------------------
-- Path helpers --
------------------

--- Get the parent directory of a path.
---
---@param path string|Path
---
---@return Path
util.parent_directory = function(path)
  -- 'Path:parent()' has bugs on Windows, so we try 'vim.fs.dirname' first instead.
  if vim.fs and vim.fs.dirname then
    local dirname = vim.fs.dirname(tostring(path))
    if dirname ~= nil then
      return Path:new(dirname)
    end
  end

  return Path:new(path):parent()
end

------------------------------------
-- Miscellaneous helper functions --
------------------------------------

---@enum OSType
util.OSType = {
  Linux = "Linux",
  Wsl = "Wsl",
  Windows = "Windows",
  Darwin = "Darwin",
}

util._current_os = nil

---Get the running operating system.
---Reference https://vi.stackexchange.com/a/2577/33116
---@return OSType
util.get_os = function()
  if util._current_os ~= nil then
    return util._current_os
  end

  local this_os
  if vim.fn.has "win32" == 1 then
    this_os = util.OSType.Windows
  else
    local sysname = vim.loop.os_uname().sysname ---@diagnostic disable-line: undefined-field
    local release = vim.loop.os_uname().release ---@diagnostic disable-line: undefined-field
    if sysname == "Linux" and string.find(release, "microsoft") then
      this_os = util.OSType.Wsl
    else
      this_os = sysname
    end
  end

  assert(this_os)
  util._current_os = this_os
  return this_os
end

---Get the strategy for opening notes
---
---@param opt obsidian.config.OpenStrategy
---@return string
util.get_open_strategy = function(opt)
  local OpenStrategy = require("obsidian.config").OpenStrategy

  -- either 'leaf', 'row' for vertically split windows, or 'col' for horizontally split windows
  local cur_layout = vim.fn.winlayout()[1]

  if vim.startswith(OpenStrategy.hsplit, opt) then
    if cur_layout ~= "col" then
      return "hsplit "
    else
      return "e "
    end
  elseif vim.startswith(OpenStrategy.vsplit, opt) then
    if cur_layout ~= "row" then
      return "vsplit "
    else
      return "e "
    end
  elseif vim.startswith(OpenStrategy.current, opt) then
    return "e "
  else
    log.err("undefined open strategy '%s'", opt)
    return "e "
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

---Toggle the checkbox on the line that the cursor is on.
util.toggle_checkbox = function()
  local line_num = unpack(vim.api.nvim_win_get_cursor(0)) -- 1-indexed
  local line = vim.api.nvim_get_current_line()

  local checkbox_pattern = "^%s*- %[.*"

  if not string.match(line, checkbox_pattern) then
    local unordered_list_pattern = "^([ ]*)[-*+] ([^%[])"

    if string.match(line, unordered_list_pattern) then
      line = string.gsub(line, unordered_list_pattern, "%1- [ ] %2")
    else
      line = string.gsub(line, "^([%s]*)", "%1- [ ] ")
    end
  elseif string.match(line, "^%s*- %[ %].*") then
    line = util.string_replace(line, "- [ ]", "- [x]", 1)
  else
    for check_char in iter { "x", "~", ">", "-" } do
      if string.match(line, "^%s*- %[" .. check_char .. "%].*") then
        line = util.string_replace(line, "- [" .. check_char .. "]", "- [ ]", 1)
        break
      end
    end
  end
  -- 0-indexed
  vim.api.nvim_buf_set_lines(0, line_num - 1, line_num, true, { line })
end

---Determines if the given date is a working day (not weekend)
---
---@param time integer
---
---@return boolean
util.is_working_day = function(time)
  local is_saturday = (os.date("%w", time) == "6")
  local is_sunday = (os.date("%w", time) == "0")
  return not (is_saturday or is_sunday)
end

---Determines the last working day before a given time
---
---@param time integer
---@return integer
util.working_day_before = function(time)
  local previous_day = time - (24 * 60 * 60)
  if util.is_working_day(previous_day) then
    return previous_day
  else
    return util.working_day_before(previous_day)
  end
end

---Determines the next working day before a given time
---
---@param time integer
---@return integer
util.working_day_after = function(time)
  local next_day = time + (24 * 60 * 60)
  if util.is_working_day(next_day) then
    return next_day
  else
    return util.working_day_after(next_day)
  end
end

---@return table - tuple containing {bufnr, winnr, row, col}
util.get_active_window_cursor_location = function()
  local buf = vim.api.nvim_win_get_buf(0)
  local win = vim.api.nvim_get_current_win()
  local row, col = unpack(vim.api.nvim_win_get_cursor(win))
  local location = { buf, win, row, col }
  return location
end

---Determines if cursor is currently inside markdown link.
---
---@param line string|nil - line to check or current line if nil
---@param col  integer|nil - column to check or current column if nil (1-indexed)
---@param include_naked_urls boolean|?
---@return integer|nil, integer|nil, obsidian.search.RefTypes|? - start and end column of link (1-indexed)
util.cursor_on_markdown_link = function(line, col, include_naked_urls)
  local search = require "obsidian.search"

  local current_line = line and line or vim.api.nvim_get_current_line()
  local _, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
  cur_col = col or cur_col + 1 -- nvim_win_get_cursor returns 0-indexed column

  for match in iter(search.find_refs(current_line, { include_naked_urls = include_naked_urls })) do
    local open, close, m_type = unpack(match)
    if open <= cur_col and cur_col <= close then
      return open, close, m_type
    end
  end

  return nil
end

---Get the link location (path, ID, URL) and name of the link under the cursor, if there is one.
---
---@param line string|?
---@param col integer|?
---@param include_naked_urls boolean|?
---@return string|?, string|?, obsidian.search.RefTypes|?
util.cursor_link = function(line, col, include_naked_urls)
  local search = require "obsidian.search"

  local current_line = line and line or vim.api.nvim_get_current_line()

  local open, close, link_type = util.cursor_on_markdown_link(current_line, col, include_naked_urls)
  if open == nil or close == nil then
    return
  end

  local link = current_line:sub(open, close)
  local link_location, link_name
  if link_type == search.RefTypes.Markdown then
    link_location = link:gsub("^%[(.-)%]%((.*)%)$", "%2")
    link_name = link:gsub("^%[(.-)%]%((.*)%)$", "%1")
  elseif link_type == search.RefTypes.NakedUrl then
    link_location = link
    link_name = link
  elseif link_type == search.RefTypes.WikiWithAlias then
    link = util.unescape_single_backslash(link)
    -- remove boundary brackets, e.g. '[[XXX|YYY]]' -> 'XXX|YYY'
    link = link:sub(3, #link - 2)
    -- split on the "|"
    local split_idx = link:find "|"
    link_location = link:sub(1, split_idx - 1)
    link_name = link:sub(split_idx + 1)
  elseif link_type == search.RefTypes.Wiki then
    -- remove boundary brackets, e.g. '[[YYY]]' -> 'YYY'
    link = link:sub(3, #link - 2)
    link_location = link
    link_name = link
  else
    error("not implemented for " .. link_type)
  end

  return link_location, link_name, link_type
end

--- Get the tag under the cursor, if there is one.
---
---@param line string|?
---@param col integer|?
---
---@return string|?
util.cursor_tag = function(line, col)
  local search = require "obsidian.search"

  local current_line = line and line or vim.api.nvim_get_current_line()
  local _, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
  cur_col = col or cur_col + 1 -- nvim_win_get_cursor returns 0-indexed column

  for match in iter(search.find_tags(current_line)) do
    local open, close, _ = unpack(match)
    if open <= cur_col and cur_col <= close then
      return string.sub(current_line, open + 1, close)
    end
  end

  return nil
end

util.gf_passthrough = function()
  if util.cursor_on_markdown_link(nil, nil, true) then
    return "<cmd>ObsidianFollowLink<CR>"
  else
    return "gf"
  end
end

---Get the path to where a plugin is installed.
---@param name string|?
---@return string|?
util.get_src_root = function(name)
  name = name and name or "obsidian.nvim"
  for _, path in ipairs(vim.api.nvim_list_runtime_paths()) do
    if vim.endswith(path, name) then
      return path
    end
  end
  return nil
end

---Get info about a plugin.
---@param name string|?
---@return string|?
util.get_plugin_info = function(name)
  name = name and name or "obsidian.nvim"
  local src_root = util.get_src_root(name)

  if src_root ~= nil then
    local Job = require "plenary.job"
    local output, exit_code = Job:new({ ---@diagnostic disable-line: missing-fields
      command = "git",
      args = { "rev-parse", "HEAD" },
      cwd = src_root,
      enable_recording = true,
    }):sync(1000)

    if exit_code == 0 then
      return "Commit SHA: " .. output[1]
    end
  end
end

---@param cmd string
---@return string|?
util.get_external_depency_info = function(cmd)
  local Job = require "plenary.job"
  local output, exit_code = Job:new({ ---@diagnostic disable-line: missing-fields
    command = cmd,
    args = { "--version" },
    enable_recording = true,
  }):sync(1000)

  if exit_code == 0 then
    return output[1]
  end
end

---Get an iterator of (bufnr, bufname) over all named buffers. The buffer names will be absolute paths.
---
---@return function () -> (integer, string)|?
util.get_named_buffers = function()
  local bufnr = 0
  local max_bufnr = vim.fn.bufnr "$"

  ---@return integer|?
  ---@return string|?
  return function()
    bufnr = bufnr + 1
    while bufnr <= max_bufnr and (vim.fn.bufexists(bufnr) == 0 or vim.fn.bufname(bufnr) == "") do
      bufnr = bufnr + 1
    end
    if bufnr > max_bufnr then
      return nil
    else
      return bufnr, vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr))
    end
  end
end

---Insert text at current cursor position.
---@param text string
util.insert_text = function(text)
  local curpos = vim.fn.getcurpos()
  local line_num, line_col = curpos[2], curpos[3]
  local indent = string.rep(" ", line_col)

  -- Convert text to lines table so we can handle multi-line strings.
  local lines = {}
  for line in text:gmatch "[^\r\n]+" do
    lines[#lines + 1] = line
  end

  for line_index, line in pairs(lines) do
    local current_line_num = line_num + line_index - 1
    local current_line = vim.fn.getline(current_line_num)
    assert(type(current_line) == "string")

    -- Since there's no column 0, remove extra space when current line is blank.
    if current_line == "" then
      indent = indent:sub(1, -2)
    end

    local pre_txt = current_line:sub(1, line_col)
    local post_txt = current_line:sub(line_col + 1, -1)
    local inserted_txt = pre_txt .. line .. post_txt

    vim.fn.setline(current_line_num, inserted_txt)

    -- Create new line so inserted_txt doesn't replace next lines
    if line_index ~= #lines then
      vim.fn.append(current_line_num, indent)
    end
  end
end

---@param bufnr integer
---@return string
util.buf_get_full_text = function(bufnr)
  local text = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, true), "\n")
  if vim.api.nvim_get_option_value("eol", { buf = bufnr }) then
    text = text .. "\n"
  end
  return text
end

return util
