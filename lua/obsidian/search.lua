local Path = require "plenary.path"
local Job = require "plenary.job"
local Deque = require("plenary.async.structs").Deque
local scan = require "plenary.scandir"
local util = require "obsidian.util"

local M = {}

M.SEARCH_CMD = { "rg", "--no-config", "--fixed-strings", "--type=md" }

---@param dir string|Path
---@param term string
---@param opts string[]|?
---@param quote boolean|?
---@return string[]
M.build_search_cmd = function(dir, term, opts, quote)
  if quote == nil then
    quote = true
  end
  local norm_dir = vim.fs.normalize(tostring(dir))
  local cmd = vim.tbl_flatten {
    M.SEARCH_CMD,
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
---@param term string
---@param opts string[]|?
---@param on_match function(MatchData)
---@param on_exit function(integer) |?
M.search_async = function(dir, term, opts, on_match, on_exit)
  local cmd = M.build_search_cmd(dir, term, opts, false)
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

M.FIND_CMD = { "rg", "--no-config", "--files", "--type=md" }

---Build the 'rg' command for finding files.
---
---@param path string|?
---@param sort_by string|?
---@param sort_reversed boolean|?
---@param term string|?
---@param quote boolean|?
---@return string[]
M.build_find_cmd = function(path, sort_by, sort_reversed, term, opts, quote)
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
  return vim.tbl_flatten { M.FIND_CMD, opts and opts or {}, additional_opts }
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
---@param on_match function(string)
---@param on_exit function(integer) |?
M.find_async = function(dir, term, sort_by, sort_reversed, opts, on_match, on_exit)
  local norm_dir = vim.fs.normalize(tostring(dir))
  local cmd = M.build_find_cmd(norm_dir, sort_by, sort_reversed, term, opts, false)
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

---Find all notes with the given file_name recursively in a directory.
---
---@param dir string|Path
---@param note_file_name string
---@param callback function(Path[])
M.find_notes_async = function(dir, note_file_name, callback)
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
