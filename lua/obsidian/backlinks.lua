local abc = require "obsidian.abc"
local async = require "plenary.async"
local channel = require("plenary.async.control").channel
local AsyncExecutor = require("obsidian.async").AsyncExecutor
local LocationList = require "obsidian.location_list"
local Note = require "obsidian.note"
local search = require "obsidian.search"
local log = require "obsidian.log"
local util = require "obsidian.util"
local iter = require("obsidian.itertools").iter

local NAMESPACE = "ObsidianBacklinks"

---@class obsidian.Backlinks : obsidian.ABC
---
---@field client obsidian.Client
---@field bufnr integer
---@field winnr integer
---@field bufname string
---@field note obsidian.Note
local Backlinks = abc.new_class()

---Create a new backlinks object.
---
---@param client obsidian.Client
---@param bufnr integer|?
---@param winnr integer|?
---@param note obsidian.Note|?
---
---@return obsidian.Backlinks
Backlinks.new = function(client, bufnr, winnr, note)
  local self = Backlinks.init()
  self.client = client
  self.bufnr = bufnr and bufnr or vim.fn.bufnr()
  self.winnr = winnr and winnr or vim.fn.winnr()
  self.bufname = vim.api.nvim_buf_get_name(self.bufnr)
  self.note = note and note or Note.from_file(self.bufname)
  return self
end

---@class BacklinkMatches
---@field note obsidian.Note
---@field matches BacklinkMatch[]

---@class BacklinkMatch
---@field line integer
---@field text string

--- Gather backlinks to the buffer.
---
---@return BacklinkMatches[]
Backlinks._gather = function(self)
  local opts = search.SearchOpts.from_tbl {
    fixed_strings = true,
    sort_by = self.client.opts.sort_by,
    sort_reversed = self.client.opts.sort_reversed,
  }

  -- Maps paths (string) to note object and a list of matches.
  ---@type table<string, BacklinkMatch[]>
  local backlink_matches = {}
  -- Keeps track of the order of the paths.
  ---@type table<string, integer>
  local path_order = {}
  local num_paths = 0

  local tx, rx = channel.oneshot()

  -- Collect matches.
  local search_terms = {}

  for ref in iter { tostring(self.note.id), self.note:fname() } do
    if ref ~= nil then
      search_terms[#search_terms + 1] = string.format("[[%s]]", ref)
      search_terms[#search_terms + 1] = string.format("[[%s|", ref)
      search_terms[#search_terms + 1] = string.format("(%s)", ref)
    end
  end

  for alias in iter(self.note.aliases) do
    search_terms[#search_terms + 1] = string.format("[[%s]]", alias)
  end

  search.search_async(self.client.dir, util.tbl_unique(search_terms), opts, function(match)
    local path = match.path.text

    local line_matches = backlink_matches[path]
    if line_matches == nil then
      line_matches = {}
      backlink_matches[path] = line_matches
    end

    line_matches[#line_matches + 1] = { line = match.line_number, text = util.rstrip_whitespace(match.lines.text) }

    if path_order[path] == nil then
      num_paths = num_paths + 1
      path_order[path] = num_paths
    end
  end, function()
    tx()
  end)

  rx()

  ---@type BacklinkMatches[]
  local out = {}

  -- Load notes for each match and combine into array of BacklinksMatches.
  local executor = AsyncExecutor.new()
  executor:map(function(path, idx)
    local ok, res = pcall(Note.from_file_async, path, self.client.dir)
    if ok then
      out[idx] = { note = res, matches = backlink_matches[path] }
    else
      log.err("Error loading note at '%s':\n%s", path, res)
    end
  end, path_order)

  executor:join_async()

  return out
end

---Create a view for the backlinks.
---@param callback function|? (BacklinkMatch[],) -> nil
Backlinks.view = function(self, callback)
  async.run(function()
    return self:_gather()
  end, function(backlink_matches)
    vim.schedule(function()
      if not vim.tbl_isempty(backlink_matches) then
        local loclist = LocationList.new(self.client, self.bufnr, self.winnr, NAMESPACE, self.client.opts.backlinks)

        local view_lines = {}
        local highlights = {}
        local folds = {}

        for match in iter(backlink_matches) do
          -- Header for note.
          view_lines[#view_lines + 1] = (" %s"):format(match.note:display_name())
          highlights[#highlights + 1] = { group = "CursorLineNr", line = #view_lines - 1, col_start = 0, col_end = 1 }
          highlights[#highlights + 1] = { group = "Directory", line = #view_lines - 1, col_start = 2, col_end = -1 }

          local display_path = assert(self.client:vault_relative_path(match.note.path))

          -- Line for backlink within note.
          for line_match in iter(match.matches) do
            local text, ref_indices, ref_strs = search.find_and_replace_refs(line_match.text)
            local text_start = 4 + display_path:len() + tostring(line_match.line):len()
            view_lines[#view_lines + 1] = ("  %s:%s:%s"):format(display_path, line_match.line, text)

            -- Add highlights for all refs in the text.
            for i, ref_idx in ipairs(ref_indices) do
              local ref_str = ref_strs[i]
              if string.find(ref_str, tostring(self.note.id), 1, true) ~= nil then
                highlights[#highlights + 1] = {
                  group = "Search",
                  line = #view_lines - 1,
                  col_start = text_start + ref_idx[1] - 1,
                  col_end = text_start + ref_idx[2],
                }
              end
            end

            -- Add highlight for path and line number
            highlights[#highlights + 1] = {
              group = "Comment",
              line = #view_lines - 1,
              col_start = 2,
              col_end = text_start,
            }
          end

          folds[#folds + 1] = { range = { #view_lines - #match.matches, #view_lines } }
          view_lines[#view_lines + 1] = ""
        end

        -- Remove last blank line.
        view_lines[#view_lines] = nil

        loclist:render(view_lines, folds, highlights)
      end

      if callback ~= nil then
        callback(backlink_matches)
      end
    end)
  end)
end

return Backlinks
