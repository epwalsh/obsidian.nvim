local abc = require "obsidian.abc"
local async = require "plenary.async"
local channel = require("plenary.async.control").channel
local AsyncExecutor = require("obsidian.async").AsyncExecutor
local Path = require "plenary.path"
local Note = require "obsidian.note"
local search = require "obsidian.search"
local log = require "obsidian.log"
local util = require "obsidian.util"
local iter = require("obsidian.itertools").iter

local NAMESPACE = "ObsidianBacklinks"

---Parse path and line number from a line in an ObsidianBacklinks buffer.
---@param line string
local function parse_path_and_line_nr(line)
  local match, n_match = line:gsub("^  ([^:]+:%d+):.*", "%1")
  if n_match > 0 then
    local splits = vim.fn.split(match, ":")
    local path = splits[1]
    local line_nr = splits[2]
    return path, line_nr
  end

  return nil, nil
end

---Find a rogue backlinks buffer that might have been spawned by i.e. a session.
local function find_rogue_buffer()
  for v in iter(vim.api.nvim_list_bufs()) do
    if vim.fn.bufname(v) == "ObsidianBacklinks" then
      return v
    end
  end
  return nil
end

---Find pre-existing backlinks buffer, delete its windows then wipe it.
---
---@private
local function wipe_rogue_buffer()
  local bn = find_rogue_buffer()
  if bn then
    local win_ids = assert(vim.fn.win_findbuf(bn))
    for id in iter(win_ids) do
      if vim.fn.win_gettype(id) ~= "autocmd" and vim.api.nvim_win_is_valid(id) then
        vim.api.nvim_win_close(id, true)
      end
    end

    vim.api.nvim_buf_set_name(bn, "")
    vim.schedule(function()
      pcall(vim.api.nvim_buf_delete, bn, {})
    end)
  end
end

---@class obsidian.Backlinks : obsidian.ABC
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

---Gather backlinks to the buffer.
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
        -- Get current window and save view so we can return focus after.
        local cur_winnr = vim.api.nvim_get_current_win()
        local cur_win_view = vim.fn.winsaveview()

        -- Clear any existing backlinks buffer.
        wipe_rogue_buffer()

        -- Create namespace (if it doesn't already exist).
        local ns_id = vim.api.nvim_create_namespace(NAMESPACE)

        -- Open buffer.
        vim.api.nvim_command("botright " .. tostring(self.client.opts.backlinks.height) .. "split ObsidianBacklinks")

        -- Configure buffer.
        self:_set_buffer_options()

        -- Render buffer lines.
        self:_render_buffer_lines(ns_id, backlink_matches)

        -- Return focus to the previous window and restore view.
        vim.api.nvim_set_current_win(cur_winnr)
        vim.fn.winrestview(cur_win_view) ---@diagnostic disable-line: param-type-mismatch
      end

      if callback ~= nil then
        callback(backlink_matches)
      end
    end)
  end)
end

Backlinks._set_buffer_options = function(self)
  vim.cmd "setlocal nonu"
  vim.cmd "setlocal nornu"
  vim.cmd "setlocal winfixheight"

  vim.opt_local.filetype = "ObsidianBacklinks"
  vim.opt_local.buftype = "nofile"
  vim.opt_local.swapfile = false
  vim.opt_local.buflisted = false
  vim.opt_local.wrap = self.client.opts.backlinks.wrap
  vim.opt_local.spell = false
  vim.opt_local.list = false
  vim.opt_local.signcolumn = "no"
  vim.opt_local.foldmethod = "manual"
  vim.opt_local.foldcolumn = "0"
  vim.opt_local.foldlevel = 3
  vim.opt_local.foldenable = false

  vim.api.nvim_buf_set_var(0, "obsidian_vault_dir", tostring(self.client.dir))
  vim.api.nvim_buf_set_var(0, "obsidian_parent_win", self.winnr)

  vim.api.nvim_buf_set_keymap(
    0,
    "n",
    "<CR>",
    [[<cmd>lua require("obsidian.backlinks").open_or_fold()<CR>]],
    { silent = true, noremap = true, nowait = true }
  )

  vim.wo.foldtext = [[v:lua.require("obsidian.backlinks").foldtext()]]
end

---@param ns_id integer
---@param backlink_matches BacklinkMatches[]
Backlinks._render_buffer_lines = function(self, ns_id, backlink_matches)
  vim.opt_local.readonly = false
  vim.opt_local.modifiable = true

  vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)

  -- Render lines.
  local view_lines = {}
  local highlights = {}
  local folds = {}

  for match in iter(backlink_matches) do
    -- Header for note.
    view_lines[#view_lines + 1] = (" %s"):format(match.note:display_name())
    highlights[#highlights + 1] = { group = "CursorLineNr", line = #view_lines - 1, col_start = 0, col_end = 1 }
    highlights[#highlights + 1] = { group = "Directory", line = #view_lines - 1, col_start = 2, col_end = -1 }

    -- Line for backlink within note.
    for line_match in iter(match.matches) do
      local display_path = assert(self.client:vault_relative_path(match.note.path))
      local text, ref_indices, ref_strs = search.find_and_replace_refs(line_match.text)
      local text_start = 4 + display_path:len() + tostring(line_match.line):len()
      view_lines[#view_lines + 1] = ("  %s:%s:%s"):format(display_path, line_match.line, text)

      -- Add highlights for all refs in the text.
      for i, ref_idx in ipairs(ref_indices) do
        local ref_str = ref_strs[i]
        if string.find(ref_str, tostring(self.note.id), 1, true) ~= nil then
          table.insert(highlights, {
            group = "Search",
            line = #view_lines - 1,
            col_start = text_start + ref_idx[1] - 1,
            col_end = text_start + ref_idx[2],
          })
        end
      end

      -- Add highlight for path and line number
      table.insert(highlights, {
        group = "Comment",
        line = #view_lines - 1,
        col_start = 2,
        col_end = text_start,
      })
    end

    table.insert(folds, { range = { #view_lines - #match.matches, #view_lines } })
    table.insert(view_lines, "")
  end

  -- Remove last blank line.
  view_lines[#view_lines] = nil

  -- Set the lines.
  vim.api.nvim_buf_set_lines(0, 0, -1, false, view_lines)

  -- Render highlights.
  for _, hl in pairs(highlights) do
    vim.api.nvim_buf_add_highlight(0, ns_id, hl.group, hl.line, hl.col_start, hl.col_end)
  end

  -- Create folds.
  for _, fold in pairs(folds) do
    vim.api.nvim_cmd({ range = fold.range, cmd = "fold" }, {})
  end

  -- Lock the buffer.
  vim.opt_local.readonly = true
  vim.opt_local.modifiable = false
end

Backlinks.open_or_fold = function()
  local vault_dir = Path:new(vim.api.nvim_buf_get_var(0, "obsidian_vault_dir"))
  local parent_win = vim.api.nvim_buf_get_var(0, "obsidian_parent_win")
  local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, true)[1]
  local path, line_nr = parse_path_and_line_nr(line)
  if path ~= nil then
    local full_path = vault_dir / path
    vim.api.nvim_command(("%swincmd w"):format(parent_win))
    vim.api.nvim_command(("e %s"):format(full_path))
    if line_nr ~= nil then
      vim.api.nvim_win_set_cursor(0, { tonumber(line_nr), 0 })
    end
  elseif string.len(line) > 0 then
    vim.cmd "normal! za" -- toggle fold
  end
end

Backlinks.foldtext = function()
  local foldstart = vim.api.nvim_get_vvar "foldstart"
  local foldend = vim.api.nvim_get_vvar "foldend"
  local num_links = foldend - foldstart

  local line = vim.api.nvim_buf_get_lines(0, foldstart - 1, foldstart, true)[1]

  local match, _ = line:gsub("^ (.+)", " %1 " .. ("(%s link%s)"):format(num_links, num_links > 1 and "s" or ""))
  return match
end

return Backlinks
