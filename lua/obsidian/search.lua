local Deque = require("plenary.async.structs").Deque
local scan = require "plenary.scandir"

local Path = require "obsidian.path"
local abc = require "obsidian.abc"
local util = require "obsidian.util"
local iter = require("obsidian.itertools").iter
local run_job_async = require("obsidian.async").run_job_async
local compat = require "obsidian.compat"

local M = {}

M._BASE_CMD = { "rg", "--no-config", "--type=md" }
M._SEARCH_CMD = compat.flatten { M._BASE_CMD, "--json" }
M._FIND_CMD = compat.flatten { M._BASE_CMD, "--files" }

---@enum obsidian.search.RefTypes
M.RefTypes = {
  WikiWithAlias = "WikiWithAlias",
  Wiki = "Wiki",
  Markdown = "Markdown",
  NakedUrl = "NakedUrl",
  FileUrl = "FileUrl",
  MailtoUrl = "MailtoUrl",
  Tag = "Tag",
  BlockID = "BlockID",
  Highlight = "Highlight",
}

---@enum obsidian.search.Patterns
M.Patterns = {
  -- Tags
  TagCharsOptional = "[A-Za-z0-9_/-]*",
  TagCharsRequired = "[A-Za-z]+[A-Za-z0-9_/-]*[A-Za-z0-9]+", -- assumes tag is at least 2 chars
  Tag = "#[A-Za-z]+[A-Za-z0-9_/-]*[A-Za-z0-9]+",

  -- Miscellaneous
  Highlight = "==[^=]+==", -- ==text==

  -- References
  WikiWithAlias = "%[%[[^][%|]+%|[^%]]+%]%]", -- [[xxx|yyy]]
  Wiki = "%[%[[^][%|]+%]%]", -- [[xxx]]
  Markdown = "%[[^][]+%]%([^%)]+%)", -- [yyy](xxx)
  NakedUrl = "https?://[a-zA-Z0-9._-]+[a-zA-Z0-9._#/=&?:+%%-]+[a-zA-Z0-9/]", -- https://xyz.com
  FileUrl = "file:/[/{2}]?.*", -- file:///
  MailtoUrl = "mailto:.*", -- mailto:emailaddress
  BlockID = util.BLOCK_PATTERN .. "$", -- ^hello-world
}

---@type table<obsidian.search.RefTypes, { ignore_if_escape_prefix: boolean|? }>
M.PatternConfig = {
  [M.RefTypes.Tag] = { ignore_if_escape_prefix = true },
}

--- Find all matches of a pattern
---
---@param s string
---@param pattern_names obsidian.search.RefTypes[]
---
---@return { [1]: integer, [2]: integer, [3]: obsidian.search.RefTypes }[]
M.find_matches = function(s, pattern_names)
  -- First find all inline code blocks so we can skip reference matches inside of those.
  local inline_code_blocks = {}
  for m_start, m_end in util.gfind(s, "`[^`]*`") do
    inline_code_blocks[#inline_code_blocks + 1] = { m_start, m_end }
  end

  local matches = {}
  for pattern_name in iter(pattern_names) do
    local pattern = M.Patterns[pattern_name]
    local pattern_cfg = M.PatternConfig[pattern_name]
    local search_start = 1
    while search_start < #s do
      local m_start, m_end = string.find(s, pattern, search_start)
      if m_start ~= nil and m_end ~= nil then
        -- Check if we're inside a code block.
        local inside_code_block = false
        for code_block_boundary in iter(inline_code_blocks) do
          if code_block_boundary[1] < m_start and m_end < code_block_boundary[2] then
            inside_code_block = true
            break
          end
        end

        if not inside_code_block then
          -- Check if this match overlaps with any others (e.g. a naked URL match would be contained in
          -- a markdown URL).
          local overlap = false
          for match in iter(matches) do
            if (match[1] <= m_start and m_start <= match[2]) or (match[1] <= m_end and m_end <= match[2]) then
              overlap = true
              break
            end
          end

          -- Check if we should skip to an escape sequence before the pattern.
          local skip_due_to_escape = false
          if
            pattern_cfg ~= nil
            and pattern_cfg.ignore_if_escape_prefix
            and string.sub(s, m_start - 1, m_start - 1) == [[\]]
          then
            skip_due_to_escape = true
          end

          if not overlap and not skip_due_to_escape then
            matches[#matches + 1] = { m_start, m_end, pattern_name }
          end
        end

        search_start = m_end
      else
        break
      end
    end
  end

  -- Sort results by position.
  table.sort(matches, function(a, b)
    return a[1] < b[1]
  end)

  return matches
end

--- Find inline highlights
---
---@param s string
---
---@return { [1]: integer, [2]: integer, [3]: obsidian.search.RefTypes }[]
M.find_highlight = function(s)
  local matches = {}
  for match in iter(M.find_matches(s, { M.RefTypes.Highlight })) do
    -- Remove highlights that begin/end with whitespace
    local match_start, match_end, _ = unpack(match)
    local text = string.sub(s, match_start + 2, match_end - 2)
    if util.strip_whitespace(text) == text then
      matches[#matches + 1] = match
    end
  end
  return matches
end

---@class obsidian.search.FindRefsOpts
---
---@field include_naked_urls boolean|?
---@field include_tags boolean|?
---@field include_file_urls boolean|?
---@field include_block_ids boolean|?

--- Find refs and URLs.
---@param s string the string to search
---@param opts obsidian.search.FindRefsOpts|?
---
---@return { [1]: integer, [2]: integer, [3]: obsidian.search.RefTypes }[]
M.find_refs = function(s, opts)
  opts = opts and opts or {}

  local pattern_names = { M.RefTypes.WikiWithAlias, M.RefTypes.Wiki, M.RefTypes.Markdown }
  if opts.include_naked_urls then
    pattern_names[#pattern_names + 1] = M.RefTypes.NakedUrl
  end
  if opts.include_tags then
    pattern_names[#pattern_names + 1] = M.RefTypes.Tag
  end
  if opts.include_file_urls then
    pattern_names[#pattern_names + 1] = M.RefTypes.FileUrl
  end
  if opts.include_block_ids then
    pattern_names[#pattern_names + 1] = M.RefTypes.BlockID
  end

  return M.find_matches(s, pattern_names)
end

--- Find all tags in a string.
---@param s string the string to search
---
---@return {[1]: integer, [2]: integer, [3]: obsidian.search.RefTypes}[]
M.find_tags = function(s)
  local matches = {}
  -- NOTE: we search over all reference types to make sure we're not including anchor links within
  -- references, which otherwise look just like tags.
  for match in iter(M.find_refs(s, { include_naked_urls = true, include_tags = true })) do
    local _, _, m_type = unpack(match)
    if m_type == M.RefTypes.Tag then
      matches[#matches + 1] = match
    end
  end
  return matches
end

--- Replace references of the form '[[xxx|xxx]]', '[[xxx]]', or '[xxx](xxx)' with their title.
---
---@param s string
---
---@return string
M.replace_refs = function(s)
  local out, _ = string.gsub(s, "%[%[[^%|%]]+%|([^%]]+)%]%]", "%1")
  out, _ = out:gsub("%[%[([^%]]+)%]%]", "%1")
  out, _ = out:gsub("%[([^%]]+)%]%([^%)]+%)", "%1")
  return out
end

--- Find all refs in a string and replace with their titles.
---
---@param s string
--
---@return string
---@return table
---@return string[]
M.find_and_replace_refs = function(s)
  local pieces = {}
  local refs = {}
  local is_ref = {}
  local matches = M.find_refs(s)
  local last_end = 1
  for _, match in pairs(matches) do
    local m_start, m_end, _ = unpack(match)
    assert(type(m_start) == "number")
    if last_end < m_start then
      table.insert(pieces, string.sub(s, last_end, m_start - 1))
      table.insert(is_ref, false)
    end
    local ref_str = string.sub(s, m_start, m_end)
    table.insert(pieces, M.replace_refs(ref_str))
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

--- Find all code block boundaries in a list of lines.
---
---@param lines string[]
---
---@return { [1]: integer, [2]: integer }[]
M.find_code_blocks = function(lines)
  ---@type { [1]: integer, [2]: integer }[]
  local blocks = {}
  ---@type integer|?
  local start_idx
  for i, line in ipairs(lines) do
    if string.match(line, "^%s*```.*```%s*$") then
      table.insert(blocks, { i, i })
      start_idx = nil
    elseif string.match(line, "^%s*```") then
      if start_idx ~= nil then
        table.insert(blocks, { start_idx, i })
        start_idx = nil
      else
        start_idx = i
      end
    end
  end
  return blocks
end

---@class obsidian.search.SearchOpts : obsidian.ABC
---
---@field sort_by obsidian.config.SortBy|?
---@field sort_reversed boolean|?
---@field fixed_strings boolean|?
---@field ignore_case boolean|?
---@field smart_case boolean|?
---@field exclude string[]|? paths to exclude
---@field max_count_per_file integer|?
---@field escape_path boolean|?
---@field include_non_markdown boolean|?
local SearchOpts = abc.new_class {
  __tostring = function(self)
    return string.format("search.SearchOpts(%s)", vim.inspect(self:as_tbl()))
  end,
}

M.SearchOpts = SearchOpts

---@param opts obsidian.search.SearchOpts|table<string, any>
---@return obsidian.search.SearchOpts
SearchOpts.from_tbl = function(opts)
  setmetatable(opts, SearchOpts.mt)
  return opts
end

---@return obsidian.search.SearchOpts
SearchOpts.default = function()
  return SearchOpts.from_tbl {}
end

---@param other obsidian.search.SearchOpts|table
---@return obsidian.search.SearchOpts
SearchOpts.merge = function(self, other)
  return SearchOpts.from_tbl(vim.tbl_extend("force", self:as_tbl(), SearchOpts.from_tbl(other):as_tbl()))
end

---@param path string
SearchOpts.add_exclude = function(self, path)
  if self.exclude == nil then
    self.exclude = {}
  end
  self.exclude[#self.exclude + 1] = path
end

---@return string[]
SearchOpts.to_ripgrep_opts = function(self)
  local opts = {}

  if self.sort_by ~= nil then
    local sort = "sortr" -- default sort is reverse
    if self.sort_reversed == false then
      sort = "sort"
    end
    opts[#opts + 1] = "--" .. sort .. "=" .. self.sort_by
  end

  if self.fixed_strings then
    opts[#opts + 1] = "--fixed-strings"
  end

  if self.ignore_case then
    opts[#opts + 1] = "--ignore-case"
  end

  if self.smart_case then
    opts[#opts + 1] = "--smart-case"
  end

  if self.exclude ~= nil then
    assert(type(self.exclude) == "table")
    for path in iter(self.exclude) do
      opts[#opts + 1] = "-g!" .. path
    end
  end

  if self.max_count_per_file ~= nil then
    opts[#opts + 1] = "-m=" .. self.max_count_per_file
  end

  return opts
end

---@param dir string|obsidian.Path
---@param term string|string[]
---@param opts obsidian.search.SearchOpts|?
---
---@return string[]
M.build_search_cmd = function(dir, term, opts)
  opts = SearchOpts.from_tbl(opts and opts or {})

  local search_terms
  if type(term) == "string" then
    search_terms = { "-e", term }
  else
    search_terms = {}
    for t in iter(term) do
      search_terms[#search_terms + 1] = "-e"
      search_terms[#search_terms + 1] = t
    end
  end

  local path = tostring(Path.new(dir):resolve { strict = true })
  if opts.escape_path then
    path = assert(vim.fn.fnameescape(path))
  end

  return compat.flatten {
    M._SEARCH_CMD,
    opts:to_ripgrep_opts(),
    search_terms,
    path,
  }
end

--- Build the 'rg' command for finding files.
---
---@param path string|?
---@param term string|?
---@param opts obsidian.search.SearchOpts|?
---
---@return string[]
M.build_find_cmd = function(path, term, opts)
  opts = SearchOpts.from_tbl(opts and opts or {})

  local additional_opts = {}

  if term ~= nil then
    local valid_extensions = require("obsidian.patterns").file_extensions
    if opts.include_non_markdown then
      term = "*" .. term .. "*"
    else
      -- Check if term does not already have a valid extension
      local has_valid_extension = false
      for _, ext in ipairs(valid_extensions) do
        if vim.endswith(term, ext) then
          has_valid_extension = true
          break
        end
      end

      if not has_valid_extension then
        term = "*" .. term .. table.concat(valid_extensions, ",*") -- Match all valid extensions
      else
        term = "*" .. term
      end
    end

    additional_opts[#additional_opts + 1] = "-g"
    additional_opts[#additional_opts + 1] = term
  end

  if opts.ignore_case then
    additional_opts[#additional_opts + 1] = "--glob-case-insensitive"
  end

  if path ~= nil and path ~= "." then
    if opts.escape_path then
      path = assert(vim.fn.fnameescape(tostring(path)))
    end
    additional_opts[#additional_opts + 1] = path
  end

  return compat.flatten { M._FIND_CMD, opts:to_ripgrep_opts(), additional_opts }
end

--- Build the 'rg' grep command for pickers.
---
---@param opts obsidian.search.SearchOpts|?
---
---@return string[]
M.build_grep_cmd = function(opts)
  opts = SearchOpts.from_tbl(opts and opts or {})

  return compat.flatten {
    M._BASE_CMD,
    opts:to_ripgrep_opts(),
    "--column",
    "--line-number",
    "--no-heading",
    "--with-filename",
    "--color=never",
  }
end

---@class MatchPath
---
---@field text string

---@class MatchText
---
---@field text string

---@class SubMatch
---
---@field match MatchText
---@field start integer
---@field end integer

---@class MatchData
---
---@field path MatchPath
---@field lines MatchText
---@field line_number integer
---@field absolute_offset integer
---@field submatches SubMatch[]

--- Search markdown files in a directory for a given term. Return an iterator
--- over `MatchData`.
---
---@param dir string|obsidian.Path
---@param term string
---@param opts obsidian.search.SearchOpts|?
---
---@return function
M.search = function(dir, term, opts)
  local matches = Deque.new()
  local done = false

  M.search_async(dir, term, opts, function(match_data)
    matches:pushright(match_data)
  end, function(_)
    done = true
  end)

  ---Iterator over matches.
  ---
  ---@return MatchData|?
  return function()
    while true do
      if not matches:is_empty() then
        return matches:popleft()
      elseif matches:is_empty() and done then
        return nil
      else
        vim.wait(100)
      end
    end
  end
end

--- An async version of `.search()`. Each match is passed to the `on_match` callback.
---
---@param dir string|obsidian.Path
---@param term string|string[]
---@param opts obsidian.search.SearchOpts|?
---@param on_match fun(match: MatchData)
---@param on_exit fun(exit_code: integer)|?
M.search_async = function(dir, term, opts, on_match, on_exit)
  local cmd = M.build_search_cmd(dir, term, opts)
  run_job_async(cmd[1], { unpack(cmd, 2) }, function(line)
    local data = vim.json.decode(line)
    if data["type"] == "match" then
      local match_data = data.data
      on_match(match_data)
    end
  end, function(code)
    if on_exit ~= nil then
      on_exit(code)
    end
  end)
end

--- Find markdown files in a directory matching a given term. Return an iterator
--- over file names.
---
---@param dir string|obsidian.Path
---@param term string
---@param opts obsidian.search.SearchOpts|?
---
---@return function
M.find = function(dir, term, opts)
  local paths = Deque.new()
  local done = false

  M.find_async(dir, term, opts, function(path)
    paths:pushright(path)
  end, function(_)
    done = true
  end)

  --- Iterator over matches.
  ---
  ---@return MatchData|?
  return function()
    while true do
      if not paths:is_empty() then
        return paths:popleft()
      elseif paths:is_empty() and done then
        return nil
      else
        vim.wait(100)
      end
    end
  end
end

--- An async version of `.find()`. Each matching path is passed to the `on_match` callback.
---
---@param dir string|obsidian.Path
---@param term string
---@param opts obsidian.search.SearchOpts|?
---@param on_match fun(path: string)
---@param on_exit fun(exit_code: integer)|?
M.find_async = function(dir, term, opts, on_match, on_exit)
  local norm_dir = Path.new(dir):resolve { strict = true }
  local cmd = M.build_find_cmd(tostring(norm_dir), term, opts)
  run_job_async(cmd[1], { unpack(cmd, 2) }, function(line)
    on_match(line)
  end, function(code)
    if on_exit ~= nil then
      on_exit(code)
    end
  end)
end

--- Find all notes with the given file_name recursively in a directory.
---
---@param dir string|obsidian.Path
---@param note_file_name string
---@param callback fun(paths: obsidian.Path[])
M.find_notes_async = function(dir, note_file_name, callback)
  if not vim.endswith(note_file_name, ".md") then
    note_file_name = note_file_name .. ".md"
  end

  local notes = {}
  local root_dir = Path.new(dir):resolve { strict = true }

  local visit_dir = function(entry)
    ---@type obsidian.Path
    ---@diagnostic disable-next-line: assign-type-mismatch
    local note_path = Path:new(entry) / note_file_name
    if note_path:is_file() then
      notes[#notes + 1] = note_path
    end
  end

  -- We must separately check the vault's root dir because scan_dir will
  -- skip it, but Obsidian does allow root-level notes.
  visit_dir(root_dir)

  scan.scan_dir_async(root_dir.filename, {
    hidden = false,
    add_dirs = false,
    only_dirs = true,
    respect_gitignore = true,
    on_insert = visit_dir,
    on_exit = function(_)
      callback(notes)
    end,
  })
end

return M
