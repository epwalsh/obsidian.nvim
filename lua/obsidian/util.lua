local scan = require "plenary.scandir"
local Path = require "plenary.path"
local Job = require "plenary.job"
local echo = require "obsidian.echo"

local util = {}

---Get the strategy for opening notes
---
---@param opt "current"|"vsplit"|"hsplit"
---@return string
util.get_open_strategy = function(opt)
  local strategy = "e "
  if opt == "hsplit" then
    strategy = "sp "
  elseif opt == "vsplit" then
    strategy = "vsp "
  end
  return strategy
end

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

---Check if a table (list) contains a key.
---
---@param table table
---@param needle any
---@return boolean
util.contains_key = function(table, needle)
  for key, _ in pairs(table) do
    if key == needle then
      return true
    end
  end
  return false
end

---Return a new table (list) with only the unique values of the original.
---
---@param table table
---@return any[]
util.unique = function(table)
  local out = {}
  for _, val in pairs(table) do
    if not util.contains(out, val) then
      out[#out + 1] = val
    end
  end
  return out
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

---Find all notes with the given file_name recursively in a directory.
---
---@param dir string|Path
---@param note_file_name string
---@return Path[]
util.find_note = function(dir, note_file_name)
  local Note = require "obsidian.note"

  local notes = {}
  local root_dir = vim.fs.normalize(tostring(dir))

  local visit_dir = function(entry)
    ---@type Path
    ---@diagnostic disable-next-line: assign-type-mismatch
    local note_path = Path:new(entry) / note_file_name
    if note_path:is_file() then
      local ok, _ = pcall(Note.from_file, note_path, root_dir)
      if ok then
        table.insert(notes, note_path)
      end
    end
  end

  -- We must separately check the vault's root dir because scan_dir will
  -- skip it, but Obsidian does allow root-level notes.
  visit_dir(root_dir)

  scan.scan_dir(root_dir, {
    hidden = false,
    add_dirs = false,
    only_dirs = true,
    respect_gitignore = true,
    on_insert = visit_dir,
  })

  return notes
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

  -- Spaces in URLs are always safely encoded with `%20`, but not always safe
  -- with `+`. For example, `+` in a query param's value will be interpreted
  -- as a literal plus-sign if the decoder is using JavaScript's `decodeURI`
  -- function.
  url = url:gsub(" ", "%%20")
  return url
end

util.SEARCH_CMD = { "rg", "--no-config", "--fixed-strings", "--type=md" }
util.FIND_CMD = { "rg", "--no-config", "--files", "--type=md" }

---Build the 'rg' command for finding files.
---
---@param path string|?
---@param sort_by string|?
---@param sort_reversed boolean|?
---@param term string|?
---@param quote boolean|?
---@return string[]
util.build_find_cmd = function(path, sort_by, sort_reversed, term, quote)
  if quote == nil then
    quote = true
  end
  local additional_opts = {}
  if sort_by ~= nil then
    local sort = "sortr" -- default sort is reverse
    if sort_reversed == false then
      sort = "sort"
    end
    additional_opts[#additional_opts + 1] = "--" .. sort
    additional_opts[#additional_opts + 1] = sort_by
  end
  if term ~= nil then
    term = "*" .. term .. "*.md"
    additional_opts[#additional_opts + 1] = "-g"
    additional_opts[#additional_opts + 1] = quote and util.quote(term) or term
  end
  if path ~= nil and path ~= "." then
    additional_opts[#additional_opts + 1] = tostring(path)
  end
  return vim.tbl_flatten { util.FIND_CMD, additional_opts }
end

---@param dir string|Path
---@param term string
---@param opts string[]|?
---@param quote boolean|?
---@return string[]
util.build_search_cmd = function(dir, term, opts, quote)
  if quote == nil then
    quote = true
  end
  local norm_dir = vim.fs.normalize(tostring(dir))
  local cmd = vim.tbl_flatten {
    util.SEARCH_CMD,
    "--json",
    opts and opts or {},
    quote and util.quote(term) or term,
    quote and util.quote(norm_dir) or norm_dir,
  }
  return cmd
end

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
---@param opts string[]|?
---@return function
util.search = function(dir, term, opts)
  local cmd = table.concat(util.build_search_cmd(dir, term, opts), " ")

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

---An async version of `util.search()`. Each match is passed to the `on_match` callback.
---
---@param dir string|Path
---@param term string
---@param opts string[]|?
---@param on_match function(MatchData)
---@param on_exit function(integer) |?
util.search_async = function(dir, term, opts, on_match, on_exit)
  local cmd = util.build_search_cmd(dir, term, opts, false)
  Job:new({
    command = cmd[1],
    args = { unpack(cmd, 2) },
    on_stdout = function(err, line)
      assert(not err, err)
      local data = vim.json.decode(line)
      if data["type"] == "match" then
        local match_data = data.data
        on_match(match_data)
      end
    end,
    on_exit = function(_, code, _)
      if on_exit ~= nil then
        on_exit(code)
      end
    end,
  }):start()
end

---Find markdown files in a directory matching a given term. Return an iterator
---over file names.
---
---@param dir string|Path
---@param term string
---@param sort_by string|?
---@param sort_reversed boolean|?
---@return function
util.find = function(dir, term, sort_by, sort_reversed)
  local norm_dir = vim.fs.normalize(tostring(dir))
  local cmd = table.concat(util.build_find_cmd(util.quote(norm_dir), sort_by, sort_reversed, term), " ")

  local handle = assert(io.popen(cmd, "r"))

  ---Iterator over matches.
  ---
  ---@return MatchData|?
  return function()
    local line = handle:read "*l"
    if line == nil then
      return nil
    end
    return line
  end
end

---An async version of `util.find()`. Each matching path is passed to the `on_match` callback.
---
---@param dir string|Path
---@param term string
---@param sort_by string|?
---@param sort_reversed boolean|?
---@param on_match function(string)
---@param on_exit function(integer) |?
util.find_async = function(dir, term, sort_by, sort_reversed, on_match, on_exit)
  local norm_dir = vim.fs.normalize(tostring(dir))
  local cmd = util.build_find_cmd(norm_dir, sort_by, sort_reversed, term, false)
  Job:new({
    command = cmd[1],
    args = { unpack(cmd, 2) },
    on_stdout = function(err, line)
      assert(not err, err)
      on_match(line)
    end,
    on_exit = function(_, code, _)
      if on_exit ~= nil then
        on_exit(code)
      end
    end,
  }):start()
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

---Check if an object is an array-like table.
---@param t any
---@return boolean
util.is_array = function(t)
  if type(t) ~= "table" then
    return false
  end

  return vim.tbl_islist(t)
end

---Check if an object is an non-array table.
---@param t any
---@return boolean
util.is_mapping = function(t)
  return type(t) == "table" and (vim.tbl_isempty(t) or not util.is_array(t))
end

---Helper function to convert a table with the list of table_params
---into a single string with params separated by spaces
---@param table_params table a table with the list of params
---@return string a single string with params separated by spaces
util.table_params_to_str = function(table_params)
  local s = ""
  for _, param in ipairs(table_params) do
    if #s > 0 then
      s = s .. " " .. param
    else
      s = param
    end
  end
  return s
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

---Determines if cursor is currently inside markdown link.
---
---@param line string|nil - line to check or current line if nil
---@param col  integer|nil - column to check or current column if nil (1-indexed)
---@return integer|nil, integer|nil - start and end column of link (1-indexed)
util.cursor_on_markdown_link = function(line, col)
  local current_line = line or vim.api.nvim_get_current_line()
  local _, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
  cur_col = col or cur_col + 1 -- nvim_win_get_cursor returns 0-indexed column

  local find_boundaries = function(pattern)
    local open, close = current_line:find(pattern)
    while open ~= nil and close ~= nil do
      if open <= cur_col and cur_col <= close then
        return open, close
      end
      open, close = current_line:find(pattern, close + 1)
    end
  end

  -- wiki link
  local open, close = find_boundaries "%[%[.-%]%]"
  if open == nil or close == nil then
    -- markdown link
    open, close = find_boundaries "%[.-%]%(.-%)"
  end

  return open, close
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
---
---@return integer
util.working_day_before = function(time)
  local previous_day = time - (24 * 60 * 60)
  if util.is_working_day(previous_day) then
    return previous_day
  else
    return util.working_day_before(previous_day)
  end
end

---
---
---@return table - tuple containing {bufnr, winnr, row, col}
util.get_active_window_cursor_location = function()
  local buf = vim.api.nvim_win_get_buf(0)
  local win = vim.api.nvim_get_current_win()
  local row, col = unpack(vim.api.nvim_win_get_cursor(win))
  local location = { buf, win, row, col }
  return location
end

---Substitute Variables inside a given Text
---
---@param text string  - name of a template in the configured templates folder
---@param client obsidian.Client
---@param title string|nil
---@return string
util.substitute_template_variables = function(text, client, title)
  local methods = client.opts.templates.substitutions or {}
  if not methods["date"] then
    methods["date"] = function()
      local date_format = client.opts.templates.date_format or "%Y-%m-%d"
      return tostring(os.date(date_format))
    end
  end
  if not methods["time"] then
    methods["time"] = function()
      local time_format = client.opts.templates.time_format or "%H:%M"
      return tostring(os.date(time_format))
    end
  end
  if title then
    methods["title"] = function()
      return title
    end
  end
  for key, value in pairs(methods) do
    text = string.gsub(text, "{{" .. key .. "}}", value())
  end
  return text
end

---Clone Template
---
---@param template_name string  - name of a template in the configured templates folder
---@param note_path string
---@param client obsidian.Client
---@param title string
util.clone_template = function(template_name, note_path, client, title)
  if client.templates_dir == nil then
    echo.err("Templates folder is not defined or does not exist", client.opts.log_level)
    return
  end
  local template_path = Path:new(client.templates_dir) / template_name
  local template_file = io.open(tostring(template_path), "r")
  local note_file = io.open(tostring(note_path), "wb")
  if not template_file then
    return error("Unable to read template at " .. template_path)
  end
  if not note_file then
    return error("Unable to write note at " .. note_path)
  end
  for line in template_file:lines "L" do
    line = util.substitute_template_variables(line, client, title)
    note_file:write(line)
  end
  template_file:close()
  note_file:close()
end

---Insert a template at the given location.
---
---@param name string - name of a template in the configured templates folder
---@param client obsidian.Client
---@param location table - a tuple with {bufnr, winnr, row, col}
util.insert_template = function(name, client, location)
  if client.templates_dir == nil then
    echo.err("Templates folder is not defined or does not exist", client.opts.log_level)
    return
  end
  local buf, win, row, col = unpack(location)
  local template_path = Path:new(client.templates_dir) / name
  local title = require("obsidian.note").from_buffer(buf, client.dir):display_name()

  local insert_lines = {}
  local template_file = io.open(tostring(template_path), "r")
  if template_file then
    local lines = template_file:lines()
    for line in lines do
      line = util.substitute_template_variables(line, client, title)
      table.insert(insert_lines, line)
    end
    template_file:close()
    table.insert(insert_lines, "")
  end

  vim.api.nvim_buf_set_text(buf, row - 1, col, row - 1, col, insert_lines)
  local new_cursor_row, _ = unpack(vim.api.nvim_win_get_cursor(win))
  vim.api.nvim_win_set_cursor(0, { new_cursor_row, 0 })
end

local IMPLEMENTATION_UNAVAILABLE = { "implementation_unavailable called from outside run_first_supported" }

---Try implementations one by one in the given order, until finding one that is supported
---
---Implementations are given as functions. If the backend of the implementation
---is unavailable (usually because a plugin is not installed), the function
---should call the `implementation_unavailable()` function from the
---`obsidian.util` module so that the next implementation in order will be
---attempted.
---
---If the implementation's backend is installed but for some reason the
---operation fails, the error will bubble up normally and the next
---implementation will not be attempted.
---
---@param command_name string - name of the command, used for formatting the error message
---@param order table - list of implementation names in the order in which they should be attempted
---@param implementations table - map of implementation name to implementation function
util.run_first_supported = function(command_name, order, implementations)
  local unavailable = {}
  local not_supported = {}
  for _, impl_name in ipairs(order) do
    local impl_function = implementations[impl_name]
    if impl_function then
      local result = { pcall(impl_function) }
      if result[1] then
        return select(2, unpack(result))
      elseif result[2] == IMPLEMENTATION_UNAVAILABLE then
        table.insert(unavailable, impl_name)
      else
        error(result[2])
      end
    else
      table.insert(not_supported, impl_name)
    end
  end

  if next(unavailable) == nil then
    error(command_name .. " cannot be run with " .. table.concat(not_supported, " or "))
  end

  local error_message
  if #unavailable == 1 then
    error_message = unavailable[1] .. " is required for " .. command_name .. " command"
  elseif #unavailable then
    error_message = "Either " .. table.concat(unavailable, " or ") .. " is required for " .. command_name .. " command"
  end

  if next(not_supported) ~= nil then
    if #not_supported == 1 then
      error_message = error_message .. ". " .. not_supported[1] .. " is not a viable option for this command"
    else
      error_message = error_message
        .. ". "
        .. table.concat(not_supported, " and ")
        .. " are not viable options for this command"
    end
  end

  error(error_message)
end

---Should be called inside implementation functions passed to
---`run_first_supported` when the implementation's backend is unavailable
---(usually because a plugin is not installed)
util.implementation_unavailable = function()
  error(IMPLEMENTATION_UNAVAILABLE)
end

util.escape_magic_characters = function(text)
  return text:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

util.gf_passthrough = function()
  if require("obsidian").util.cursor_on_markdown_link() then
    return "<cmd>ObsidianFollowLink<CR>"
  else
    return "gf"
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
  local c_start = string.sub(str, 1, 1)
  local c_end = string.sub(str, #str, #str)
  for _, enclosing_char in ipairs(util.string_enclosing_chars) do
    if c_start == enclosing_char and c_end == enclosing_char then
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

---Check if a mapping contains a key.
---@param map table
---@param key string
---@return boolean
util.mapping_has_key = function(map, key)
  for k, _ in pairs(map) do
    if key == k then
      return true
    end
  end
  return false
end

---Check if a string contains a substring.
---@param str string
---@param substr string
---@return boolean
util.string_contains = function(str, substr)
  local i = string.find(str, substr, 1, true)
  return i ~= nil
end

return util
