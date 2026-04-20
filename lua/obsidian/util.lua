local iter = require("obsidian.itertools").iter
local enumerate = require("obsidian.itertools").enumerate
local log = require "obsidian.log"
local compat = require "obsidian.compat"

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
    if vim.deep_equal(table[i], val) then
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

  return compat.is_list(t)
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

--- Clear all values from a table.
---
---@param t table
util.tbl_clear = function(t)
  for k, _ in pairs(t) do
    t[k] = nil
  end
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

local hex_to_char = function(hex)
  return string.char(tonumber(hex, 16))
end

--- Encode a string into URL-safe version.
---
---@param str string
---@param opts { keep_path_sep: boolean|? }|?
---
---@return string
util.urlencode = function(str, opts)
  opts = opts or {}
  local url = str
  url = url:gsub("\n", "\r\n")
  url = url:gsub("([^/%w _%%%-%.~])", char_to_hex)
  if not opts.keep_path_sep then
    url = url:gsub("/", char_to_hex)
  end

  -- Spaces in URLs are always safely encoded with `%20`, but not always safe
  -- with `+`. For example, `+` in a query param's value will be interpreted
  -- as a literal plus-sign if the decoder is using JavaScript's `decodeURI`
  -- function.
  url = url:gsub(" ", "%%20")
  return url
end

--- Decode a URL-encoded string.
---
---@param str string
---
---@return string
util.urldecode = function(str)
  str = str:gsub("%%(%x%x)", hex_to_char)
  return str
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

---Check if a string is a checkbox list item
---
---Supported checboox lists:
--- - [ ] foo
--- - [x] foo
--- + [x] foo
--- * [ ] foo
--- 1. [ ] foo
--- 1) [ ] foo
---
---@param s string
---@return boolean
util.is_checkbox = function(s)
  -- - [ ] and * [ ] and + [ ]
  if string.match(s, "^%s*[-+*]%s+%[.%]") ~= nil then
    return true
  end
  -- 1. [ ] and 1) [ ]
  if string.match(s, "^%s*%d+[%.%)]%s+%[.%]") ~= nil then
    return true
  end
  return false
end

---Check if a string is a valid URL.
---@param s string
---@return boolean
util.is_url = function(s)
  local search = require "obsidian.search"

  if
    string.match(util.strip_whitespace(s), "^" .. search.Patterns[search.RefTypes.NakedUrl] .. "$")
    or string.match(util.strip_whitespace(s), "^" .. search.Patterns[search.RefTypes.FileUrl] .. "$")
    or string.match(util.strip_whitespace(s), "^" .. search.Patterns[search.RefTypes.MailtoUrl] .. "$")
  then
    return true
  else
    return false
  end
end

---Checks if a given string represents an image file based on its suffix.
---
---@param s string: The input string to check.
---@return boolean: Returns true if the string ends with a supported image suffix, false otherwise.
util.is_img = function(s)
  for _, suffix in ipairs { ".png", ".jpg", ".jpeg", ".heic", ".gif", ".svg", ".ico" } do
    if vim.endswith(s, suffix) then
      return true
    end
  end
  return false
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
  if vim.startswith(str, "# ") then
    return ""
  elseif not util.has_enclosing_chars(str) then
    return select(1, string.gsub(str, [[%s+#%s.*$]], ""))
  else
    return str
  end
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

--- Count occurrences of the `pattern` in `s`.
---
---@param s string
---@param pattern string
---
---@return integer
util.string_count = function(s, pattern)
  return select(2, string.gsub(s, pattern, ""))
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
  FreeBSD = "FreeBSD",
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
    local sysname = vim.loop.os_uname().sysname
    local release = vim.loop.os_uname().release:lower()
    if sysname:lower() == "linux" and string.find(release, "microsoft") then
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
      return "split "
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

---Toggle the checkbox on the current line.
---
---@param opts table|nil Optional table containing checkbox states (e.g., {" ", "x"}).
---@param line_num number|nil Optional line number to toggle the checkbox on. Defaults to the current line.
util.toggle_checkbox = function(opts, line_num)
  -- Allow line_num to be optional, defaulting to the current line if not provided
  line_num = line_num or unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, false)[1]

  local checkboxes = opts or { " ", "x" }

  if util.is_checkbox(line) then
    for i, check_char in enumerate(checkboxes) do
      if string.match(line, "^.* %[" .. util.escape_magic_characters(check_char) .. "%].*") then
        i = i % #checkboxes
        line = util.string_replace(line, "[" .. check_char .. "]", "[" .. checkboxes[i + 1] .. "]", 1)
        break
      end
    end
  else
    local unordered_list_pattern = "^(%s*)[-*+] (.*)"
    if string.match(line, unordered_list_pattern) then
      line = string.gsub(line, unordered_list_pattern, "%1- [ ] %2")
    else
      line = string.gsub(line, "^(%s*)", "%1- [ ] ")
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
---@param include_file_urls boolean|?
---@param include_block_ids boolean|?
---@return integer|nil, integer|nil, obsidian.search.RefTypes|? - start and end column of link (1-indexed)
util.cursor_on_markdown_link = function(line, col, include_naked_urls, include_file_urls, include_block_ids)
  local search = require "obsidian.search"

  local current_line = line and line or vim.api.nvim_get_current_line()
  local _, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
  cur_col = col or cur_col + 1 -- nvim_win_get_cursor returns 0-indexed column

  for match in
    iter(search.find_refs(current_line, {
      include_naked_urls = include_naked_urls,
      include_file_urls = include_file_urls,
      include_block_ids = include_block_ids,
    }))
  do
    local open, close, m_type = unpack(match)
    if open <= cur_col and cur_col <= close then
      return open, close, m_type
    end
  end

  return nil
end

--- Deprecated, use `parse_cursor_link()` instead.
---
---@param line string|?
---@param col integer|?
---@param include_naked_urls boolean|?
---@param include_file_urls boolean|?
---
---@return string|?, string|?, obsidian.search.RefTypes|?
util.cursor_link = function(line, col, include_naked_urls, include_file_urls)
  return util.parse_cursor_link {
    line = line,
    col = col,
    include_naked_urls = include_naked_urls,
    include_file_urls = include_file_urls,
  }
end

--- Get the link location and name of the link under the cursor, if there is one.
---
---@param opts { line: string|?, col: integer|?, include_naked_urls: boolean|?, include_file_urls: boolean|?, include_block_ids: boolean|? }|?
---
---@return string|?, string|?, obsidian.search.RefTypes|?
util.parse_cursor_link = function(opts)
  opts = opts and opts or {}

  local current_line = opts.line and opts.line or vim.api.nvim_get_current_line()
  local open, close, link_type = util.cursor_on_markdown_link(
    current_line,
    opts.col,
    opts.include_naked_urls,
    opts.include_file_urls,
    opts.include_block_ids
  )
  if open == nil or close == nil then
    return
  end

  local link = current_line:sub(open, close)
  return util.parse_link(link, {
    link_type = link_type,
    include_naked_urls = opts.include_naked_urls,
    include_file_urls = opts.include_file_urls,
    include_block_ids = opts.include_block_ids,
  })
end

---@param link string
---@param opts { include_naked_urls: boolean|?, include_file_urls: boolean|?, include_block_ids: boolean|?, link_type: obsidian.search.RefTypes|? }|?
---
---@return string|?, string|?, obsidian.search.RefTypes|?
util.parse_link = function(link, opts)
  local search = require "obsidian.search"

  opts = opts and opts or {}

  local link_type = opts.link_type
  if link_type == nil then
    for match in
      iter(search.find_refs(link, {
        include_naked_urls = opts.include_naked_urls,
        include_file_urls = opts.include_file_urls,
        include_block_ids = opts.include_block_ids,
      }))
    do
      local _, _, m_type = unpack(match)
      if m_type then
        link_type = m_type
        break
      end
    end
  end

  if link_type == nil then
    return nil
  end

  local link_location, link_name
  if link_type == search.RefTypes.Markdown then
    link_location = link:gsub("^%[(.-)%]%((.*)%)$", "%2")
    link_name = link:gsub("^%[(.-)%]%((.*)%)$", "%1")
  elseif link_type == search.RefTypes.NakedUrl then
    link_location = link
    link_name = link
  elseif link_type == search.RefTypes.FileUrl then
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
  elseif link_type == search.RefTypes.BlockID then
    link_location = util.standardize_block(link)
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

util.smart_action = function()
  -- follow link if possible
  if util.cursor_on_markdown_link(nil, nil, true) then
    return "<cmd>ObsidianFollowLink<CR>"
  end

  -- show notes with tag if possible
  if util.cursor_tag(nil, nil) then
    return "<cmd>ObsidianTag<CR>"
  end

  -- toggle task if possible
  -- cycles through your custom UI checkboxes, default: [ ] [~] [>] [x]
  return "<cmd>ObsidianToggleCheckbox<CR>"
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

--- Get info about a plugin.
---
---@param name string|?
---
---@return { commit: string|?, path: string }|?
util.get_plugin_info = function(name)
  name = name and name or "obsidian.nvim"

  local src_root = util.get_src_root(name)
  if src_root == nil then
    return nil
  end

  local out = { path = src_root }

  local Job = require "plenary.job"
  local output, exit_code = Job:new({ ---@diagnostic disable-line: missing-fields
    command = "git",
    args = { "rev-parse", "HEAD" },
    cwd = src_root,
    enable_recording = true,
  }):sync(1000)

  if exit_code == 0 then
    out.commit = output[1]
  end

  return out
end

---@param cmd string
---@return string|?
util.get_external_dependency_info = function(cmd)
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
  local idx = 0
  local buffers = vim.api.nvim_list_bufs()

  ---@return integer|?
  ---@return string|?
  return function()
    while idx < #buffers do
      idx = idx + 1
      local bufnr = buffers[idx]
      if vim.api.nvim_buf_is_loaded(bufnr) then
        return bufnr, vim.api.nvim_buf_get_name(bufnr)
      end
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

--- Get the current visual selection of text and exit visual mode.
---
---@param opts { strict: boolean|? }|?
---
---@return { lines: string[], selection: string, csrow: integer, cscol: integer, cerow: integer, cecol: integer }|?
util.get_visual_selection = function(opts)
  opts = opts or {}
  -- Adapted from fzf-lua:
  -- https://github.com/ibhagwan/fzf-lua/blob/6ee73fdf2a79bbd74ec56d980262e29993b46f2b/lua/fzf-lua/utils.lua#L434-L466
  -- this will exit visual mode
  -- use 'gv' to reselect the text
  local _, csrow, cscol, cerow, cecol
  local mode = vim.fn.mode()
  if opts.strict and not vim.endswith(string.lower(mode), "v") then
    return
  end

  if mode == "v" or mode == "V" or mode == "" then
    -- if we are in visual mode use the live position
    _, csrow, cscol, _ = unpack(vim.fn.getpos ".")
    _, cerow, cecol, _ = unpack(vim.fn.getpos "v")
    if mode == "V" then
      -- visual line doesn't provide columns
      cscol, cecol = 0, 999
    end
    -- exit visual mode
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
  else
    -- otherwise, use the last known visual position
    _, csrow, cscol, _ = unpack(vim.fn.getpos "'<")
    _, cerow, cecol, _ = unpack(vim.fn.getpos "'>")
  end

  -- Swap vars if needed
  if cerow < csrow then
    csrow, cerow = cerow, csrow
    cscol, cecol = cecol, cscol
  elseif cerow == csrow and cecol < cscol then
    cscol, cecol = cecol, cscol
  end

  local lines = vim.fn.getline(csrow, cerow)
  assert(type(lines) == "table")
  if vim.tbl_isempty(lines) then
    return
  end

  -- When the whole line is selected via visual line mode ("V"), cscol / cecol will be equal to "v:maxcol"
  -- for some odd reason. So change that to what they should be here. See ':h getpos' for more info.
  local maxcol = vim.api.nvim_get_vvar "maxcol"
  if cscol == maxcol then
    cscol = string.len(lines[1])
  end
  if cecol == maxcol then
    cecol = string.len(lines[#lines])
  end

  ---@type string
  local selection
  local n = #lines
  if n <= 0 then
    selection = ""
  elseif n == 1 then
    selection = string.sub(lines[1], cscol, cecol)
  elseif n == 2 then
    selection = string.sub(lines[1], cscol) .. "\n" .. string.sub(lines[n], 1, cecol)
  else
    selection = string.sub(lines[1], cscol)
      .. "\n"
      .. table.concat(lines, "\n", 2, n - 1)
      .. "\n"
      .. string.sub(lines[n], 1, cecol)
  end

  return {
    lines = lines,
    selection = selection,
    csrow = csrow,
    cscol = cscol,
    cerow = cerow,
    cecol = cecol,
  }
end

---@param anchor obsidian.note.HeaderAnchor
---@return string
util.format_anchor_label = function(anchor)
  return string.format(" ❯ %s", anchor.header)
end

---@param opts { path: string, label: string, id: string|integer|?, anchor: obsidian.note.HeaderAnchor|?, block: obsidian.note.Block|? }
---@return string
util.wiki_link_alias_only = function(opts)
  ---@type string
  local header_or_block = ""
  if opts.anchor then
    header_or_block = string.format("#%s", opts.anchor.header)
  elseif opts.block then
    header_or_block = string.format("#%s", opts.block.id)
  end
  return string.format("[[%s%s]]", opts.label, header_or_block)
end

---@param opts { path: string, label: string, id: string|integer|?, anchor: obsidian.note.HeaderAnchor|?, block: obsidian.note.Block|? }
---@return string
util.wiki_link_path_only = function(opts)
  ---@type string
  local header_or_block = ""
  if opts.anchor then
    header_or_block = opts.anchor.anchor
  elseif opts.block then
    header_or_block = string.format("#%s", opts.block.id)
  end
  return string.format("[[%s%s]]", opts.path, header_or_block)
end

---@param opts { path: string, label: string, id: string|integer|?, anchor: obsidian.note.HeaderAnchor|?, block: obsidian.note.Block|? }
---@return string
util.wiki_link_path_prefix = function(opts)
  local anchor = ""
  local header = ""
  if opts.anchor then
    anchor = opts.anchor.anchor
    header = util.format_anchor_label(opts.anchor)
  elseif opts.block then
    anchor = "#" .. opts.block.id
    header = "#" .. opts.block.id
  end

  if opts.label ~= opts.path then
    return string.format("[[%s%s|%s%s]]", opts.path, anchor, opts.label, header)
  else
    return string.format("[[%s%s]]", opts.path, anchor)
  end
end

---@param opts { path: string, label: string, id: string|integer|?, anchor: obsidian.note.HeaderAnchor|?, block: obsidian.note.Block|? }
---@return string
util.wiki_link_id_prefix = function(opts)
  local anchor = ""
  local header = ""
  if opts.anchor then
    anchor = opts.anchor.anchor
    header = util.format_anchor_label(opts.anchor)
  elseif opts.block then
    anchor = "#" .. opts.block.id
    header = "#" .. opts.block.id
  end

  if opts.id == nil then
    return string.format("[[%s%s]]", opts.label, anchor)
  elseif opts.label ~= opts.id then
    return string.format("[[%s%s|%s%s]]", opts.id, anchor, opts.label, header)
  else
    return string.format("[[%s%s]]", opts.id, anchor)
  end
end

---@param opts { path: string, label: string, id: string|integer|?, anchor: obsidian.note.HeaderAnchor|?, block: obsidian.note.Block|? }
---@return string
util.markdown_link = function(opts)
  local anchor = ""
  local header = ""
  if opts.anchor then
    anchor = opts.anchor.anchor
    header = util.format_anchor_label(opts.anchor)
  elseif opts.block then
    anchor = "#" .. opts.block.id
    header = "#" .. opts.block.id
  end

  local path = util.urlencode(opts.path, { keep_path_sep = true })
  return string.format("[%s%s](%s%s)", opts.label, header, path, anchor)
end

--- Open a buffer for the corresponding path.
---
---@param path string|obsidian.Path
---@param opts { line: integer|?, col: integer|?, cmd: string|? }|?
---@return integer bufnr
util.open_buffer = function(path, opts)
  local Path = require "obsidian.path"

  path = Path.new(path):resolve()
  opts = opts and opts or {}
  local cmd = util.strip_whitespace(opts.cmd and opts.cmd or "e")

  ---@type integer|?
  local result_bufnr

  -- Check for buffer in windows and use 'drop' command if one is found.
  for _, winnr in ipairs(vim.api.nvim_list_wins()) do
    local bufnr = vim.api.nvim_win_get_buf(winnr)
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    if bufname == tostring(path) then
      cmd = "drop"
      result_bufnr = bufnr
      break
    end
  end

  vim.cmd(string.format("%s %s", cmd, vim.fn.fnameescape(tostring(path))))
  if opts.line then
    vim.api.nvim_win_set_cursor(0, { tonumber(opts.line), opts.col and opts.col or 0 })
  end

  if not result_bufnr then
    result_bufnr = vim.api.nvim_get_current_buf()
  end

  return result_bufnr
end

--- Get a nice icon for a file or URL, if possible.
---
---@param path string
---
---@return string|?, string|? (icon, hl_group) The icon and highlight group.
util.get_icon = function(path)
  if util.is_url(path) then
    local icon = ""
    local _, hl_group = util.get_icon "blah.html"
    return icon, hl_group
  else
    local ok, res = pcall(function()
      local icon, hl_group = require("nvim-web-devicons").get_icon(path, nil, { default = true })
      return { icon, hl_group }
    end)
    if ok and type(res) == "table" then
      local icon, hlgroup = unpack(res)
      return icon, hlgroup
    elseif vim.endswith(path, ".md") then
      return ""
    end
  end
  return nil
end

-- We are very loose here because obsidian allows pretty much anything
util.ANCHOR_LINK_PATTERN = "#[%w%d][^#]*"

util.BLOCK_PATTERN = "%^[%w%d][%w%d-]*"

util.BLOCK_LINK_PATTERN = "#" .. util.BLOCK_PATTERN

--- Strip anchor links from a line.
---@param line string
---@return string, string|?
util.strip_anchor_links = function(line)
  ---@type string|?
  local anchor

  while true do
    local anchor_match = string.match(line, util.ANCHOR_LINK_PATTERN .. "$")
    if anchor_match then
      anchor = anchor or ""
      anchor = anchor_match .. anchor
      line = string.sub(line, 1, -anchor_match:len() - 1)
    else
      break
    end
  end

  return line, anchor and util.standardize_anchor(anchor)
end

--- Parse a block line from a line.
---
---@param line string
---
---@return string|?
util.parse_block = function(line)
  local block_match = string.match(line, util.BLOCK_PATTERN .. "$")
  return block_match
end

--- Strip block links from a line.
---@param line string
---@return string, string|?
util.strip_block_links = function(line)
  local block_match = string.match(line, util.BLOCK_LINK_PATTERN .. "$")
  if block_match then
    line = string.sub(line, 1, -block_match:len() - 1)
  end
  return line, block_match
end

--- Standardize a block identifier.
---@param block_id string
---@return string
util.standardize_block = function(block_id)
  if vim.startswith(block_id, "#") then
    block_id = string.sub(block_id, 2)
  end

  if not vim.startswith(block_id, "^") then
    block_id = "^" .. block_id
  end

  return block_id
end

--- Check if a line is a markdown header.
---@param line string
---@return boolean
util.is_header = function(line)
  if string.match(line, "^#+%s+[%w]+") then
    return true
  else
    return false
  end
end

--- Get the header level of a line.
---@param line string
---@return integer
util.header_level = function(line)
  local headers, match_count = string.gsub(line, "^(#+)%s+[%w]+.*", "%1")
  if match_count > 0 then
    return string.len(headers)
  else
    return 0
  end
end

---@param line string
---@return { header: string, level: integer, anchor: string }|?
util.parse_header = function(line)
  local header_start, header = string.match(line, "^(#+)%s+([^%s]+.*)$")
  if header_start and header then
    header = util.strip_whitespace(header)
    return {
      header = util.strip_whitespace(header),
      level = string.len(header_start),
      anchor = util.header_to_anchor(header),
    }
  else
    return nil
  end
end

--- Standardize a header anchor link.
---
---@param anchor string
---
---@return string
util.standardize_anchor = function(anchor)
  -- Lowercase everything.
  anchor = string.lower(anchor)
  -- Replace whitespace with "-".
  anchor = string.gsub(anchor, "%s", "-")
  -- Remove every non-alphanumeric character.
  anchor = string.gsub(anchor, "[^#%w_-]", "")
  return anchor
end

--- Transform a markdown header into an link, e.g. "# Hello World" -> "#hello-world".
---
---@param header string
---
---@return string
util.header_to_anchor = function(header)
  -- Remove leading '#' and strip whitespace.
  local anchor = util.strip_whitespace(string.gsub(header, [[^#+%s+]], ""))
  return util.standardize_anchor("#" .. anchor)
end

local INPUT_CANCELLED = "~~~INPUT-CANCELLED~~~"

--- Prompt user for an input. Returns nil if canceled, otherwise a string (possibly empty).
---
---@param prompt string
---@param opts { completion: string|?, default: string|? }|?
---
---@return string|?
util.input = function(prompt, opts)
  opts = opts or {}

  if not vim.endswith(prompt, " ") then
    prompt = prompt .. " "
  end

  local input = util.strip_whitespace(
    vim.fn.input { prompt = prompt, completion = opts.completion, default = opts.default, cancelreturn = INPUT_CANCELLED }
  )

  if input ~= INPUT_CANCELLED then
    return input
  else
    return nil
  end
end

--- Prompt user for a confirmation.
---
---@param prompt string
---
---@return boolean
util.confirm = function(prompt)
  if not vim.endswith(util.rstrip_whitespace(prompt), "[Y/n]") then
    prompt = util.rstrip_whitespace(prompt) .. " [Y/n] "
  end

  local confirmation = util.input(prompt)
  if confirmation == nil then
    return false
  end

  confirmation = string.lower(confirmation)

  if confirmation == "" or confirmation == "y" or confirmation == "yes" then
    return true
  else
    return false
  end
end

---@alias datetime_cadence "daily"

--- Parse possible relative date macros like '@tomorrow'.
---
---@param macro string
---
---@return { macro: string, offset: integer, cadence: datetime_cadence }[]
util.resolve_date_macro = function(macro)
  ---@type { macro: string, offset: integer, cadence: datetime_cadence }[]
  local out = {}
  for m, offset_days in pairs { today = 0, tomorrow = 1, yesterday = -1 } do
    m = "@" .. m
    if vim.startswith(m, macro) then
      out[#out + 1] = { macro = m, offset = offset_days, cadence = "daily" }
    end
  end
  return out
end

--- Check if a buffer is empty.
---
---@param bufnr integer|?
---
---@return boolean
util.buffer_is_empty = function(bufnr)
  bufnr = bufnr or 0
  if vim.api.nvim_buf_line_count(bufnr) > 1 then
    return false
  else
    local first_text = vim.api.nvim_buf_get_text(bufnr, 0, 0, 0, 0, {})
    if vim.tbl_isempty(first_text) or first_text[1] == "" then
      return true
    else
      return false
    end
  end
end

---Check if a string is NaN
---
---@param v any
---@return boolean
util.isNan = function(v)
  return tostring(v) == tostring(0 / 0)
end

return util
