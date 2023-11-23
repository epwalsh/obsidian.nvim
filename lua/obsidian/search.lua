local Path = require "plenary.path"
local Deque = require("plenary.async.structs").Deque
local scan = require "plenary.scandir"
local iter = require("obsidian.itertools").iter
local run_job_async = require("obsidian.async").run_job_async

local M = {}

M._BASE_CMD = { "rg", "--no-config", "--type=md" }
M._SEARCH_CMD = vim.tbl_flatten { M._BASE_CMD, "--json" }
M._FIND_CMD = vim.tbl_flatten { M._BASE_CMD, "--files" }

---@enum obsidian.search.RefTypes
M.RefTypes = {
  WikiWithAlias = "WikiWithAlias",
  Wiki = "Wiki",
  Markdown = "Markdown",
  NakedUrl = "NakedUrl",
  Tag = "Tag",
}

---@enum obsidian.search.Patterns
M.Patterns = {
  -- Miscellaneous
  TagChars = "[A-Za-z0-9_/-]*",
  Highlight = "==[^=]+==", -- ==text==

  -- References
  WikiWithAlias = "%[%[[^][%|]+%|[^%]]+%]%]", -- [[xxx|yyy]]
  Wiki = "%[%[[^][%|]+%]%]", -- [[xxx]]
  Markdown = "%[[^][]+%]%([^%)]+%)", -- [yyy](xxx)
  NakedUrl = "https?://[a-zA-Z0-9._#/=&?-]+[a-zA-Z0-9]", -- https://xyz.com
  Tag = "#[a-zA-Z0-9_/-]+", -- #tag
}

---Iterate over all matches of 'pattern' in 's'. 'gfind' is to 'find' and 'gsub' is to 'sub'.
---@param s string
---@param pattern string
---@param init integer|?
---@param plain boolean|?
M.gfind = function(s, pattern, init, plain)
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

---Find all matches of a pattern
---@param s string
---@param pattern_names table
---@return table
M.find_matches = function(s, pattern_names)
  -- First find all inline code blocks so we can skip reference matches inside of those.
  local inline_code_blocks = {}
  for m_start, m_end in M.gfind(s, "`[^`]*`") do
    inline_code_blocks[#inline_code_blocks + 1] = { m_start, m_end }
  end

  local matches = {}
  for pattern_name in iter(pattern_names) do
    local pattern = M.Patterns[pattern_name]
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

          if not overlap then
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

---Find inline highlights
---@param s string
---@return table
M.find_highlight = function(s)
  local util = require "obsidian.util"
  local matches = {}
  for match in iter(M.find_matches(s, { "Highlight" })) do
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
---@field include_naked_urls boolean|?
---@field include_tags boolean|?

---Find refs and URLs.
---@param s string the string to search
---@param opts obsidian.search.FindRefsOpts|?
---@return table
M.find_refs = function(s, opts)
  opts = opts and opts or {}

  local pattern_names = { M.RefTypes.WikiWithAlias, M.RefTypes.Wiki, M.RefTypes.Markdown }
  if opts.include_naked_urls then
    pattern_names[#pattern_names + 1] = M.RefTypes.NakedUrl
  end
  if opts.include_tags then
    pattern_names[#pattern_names + 1] = M.RefTypes.Tag
  end

  return M.find_matches(s, pattern_names)
end

---Replace references of the form '[[xxx|xxx]]', '[[xxx]]', or '[xxx](xxx)' with their title.
---
---@param s string
---@return string
M.replace_refs = function(s)
  local out, _ = string.gsub(s, "%[%[[^%|%]]+%|([^%]]+)%]%]", "%1")
  out, _ = out:gsub("%[%[([^%]]+)%]%]", "%1")
  out, _ = out:gsub("%[([^%]]+)%]%([^%)]+%)", "%1")
  return out
end

---Find all refs in a string and replace with their titles.
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
    local m_start, m_end = unpack(match)
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

---@param dir string|Path
---@param term string|string[]
---@param opts string[]|?
---@return string[]
M.build_search_cmd = function(dir, term, opts)
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

  local norm_dir = vim.fs.normalize(tostring(dir))
  local cmd = vim.tbl_flatten {
    M._SEARCH_CMD,
    opts and opts or {},
    search_terms,
    norm_dir,
  }
  return cmd
end

---Build the 'rg' command for finding files.
---
---@param path string|?
---@param sort_by string|?
---@param sort_reversed boolean|?
---@param term string|?
---@return string[]
M.build_find_cmd = function(path, sort_by, sort_reversed, term, opts)
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
    additional_opts[#additional_opts + 1] = term
  end
  if path ~= nil and path ~= "." then
    additional_opts[#additional_opts + 1] = tostring(path)
  end
  return vim.tbl_flatten { M._FIND_CMD, opts and opts or {}, additional_opts }
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
M.search = function(dir, term, opts)
  local matches = Deque.new()
  local done = false

  M.search_async(dir, term, opts, function(match_data)
    matches:pushright(match_data)
  end, function(_, _, _)
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

---An async version of `.search()`. Each match is passed to the `on_match` callback.
---
---@param dir string|Path
---@param term string|string[]
---@param opts string[]|?
---@param on_match function (match: MatchData) -> nil
---@param on_exit function|? (exit_code: integer) -> nil
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

---Find markdown files in a directory matching a given term. Return an iterator
---over file names.
---
---@param dir string|Path
---@param term string
---@param sort_by string|?
---@param sort_reversed boolean|?
---@param opts string[]|?
---@return function
M.find = function(dir, term, sort_by, sort_reversed, opts)
  local paths = Deque.new()
  local done = false

  M.find_async(dir, term, sort_by, sort_reversed, opts, function(path)
    paths:pushright(path)
  end, function(_, _, _)
    done = true
  end)

  ---Iterator over matches.
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

---An async version of `.find()`. Each matching path is passed to the `on_match` callback.
---
---@param dir string|Path
---@param term string
---@param sort_by string|?
---@param sort_reversed boolean|?
---@param opts string[]|?
---@param on_match function (string) -> nil
---@param on_exit function|? (integer) -> nil
M.find_async = function(dir, term, sort_by, sort_reversed, opts, on_match, on_exit)
  local norm_dir = vim.fs.normalize(tostring(dir))
  local cmd = M.build_find_cmd(norm_dir, sort_by, sort_reversed, term, opts)
  run_job_async(cmd[1], { unpack(cmd, 2) }, function(line)
    on_match(line)
  end, function(code)
    if on_exit ~= nil then
      on_exit(code)
    end
  end)
end

---Find all notes with the given file_name recursively in a directory.
---
---@param dir string|Path
---@param note_file_name string
---@param callback function(Path[])
M.find_notes_async = function(dir, note_file_name, callback)
  if not vim.endswith(note_file_name, ".md") then
    note_file_name = note_file_name .. ".md"
  end

  local notes = {}
  local root_dir = vim.fs.normalize(tostring(dir))

  local visit_dir = function(entry)
    ---@type Path
    ---@diagnostic disable-next-line: assign-type-mismatch
    local note_path = Path:new(entry) / note_file_name
    if note_path:is_file() then
      notes[#notes + 1] = note_path
    end
  end

  -- We must separately check the vault's root dir because scan_dir will
  -- skip it, but Obsidian does allow root-level notes.
  visit_dir(root_dir)

  scan.scan_dir_async(root_dir, {
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
