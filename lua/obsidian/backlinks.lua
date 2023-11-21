local async = require "plenary.async"
local channel = require("plenary.async.control").channel
local Path = require "plenary.path"
local Note = require "obsidian.note"
local search = require "obsidian.search"
local iter = require("obsidian.itertools").iter

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
    local win_ids = vim.fn.win_findbuf(bn)
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

---@class obsidian.Backlinks
---@field client obsidian.Client
---@field bufnr integer
---@field winnr integer
---@field bufname string
---@field note obsidian.Note
local Backlinks = {}

---Create a new backlinks object.
---
---@param client obsidian.Client
---@param bufnr integer|?
---@param winnr integer|?
---@param note obsidian.Note|?
---@return obsidian.Backlinks
Backlinks.new = function(client, bufnr, winnr, note)
  local self = setmetatable({}, { __index = Backlinks })
  self.client = client
  self.bufnr = bufnr and bufnr or vim.fn.bufnr()
  self.winnr = winnr and winnr or vim.fn.winnr()
  self.bufname = vim.api.nvim_buf_get_name(self.bufnr)
  self.note = note and note or Note.from_file(self.bufname)
  return self
end

---@class BacklinkMatch
---@field note obsidian.Note
---@field line integer
---@field text string

---Gather backlinks to the buffer.
---
---@return BacklinkMatch[]
Backlinks._gather = function(self)
  ---@param match_data MatchData
  ---@return boolean
  local is_valid_backlink = function(match_data)
    local line = match_data.lines.text
    for _, submatch in pairs(match_data.submatches) do
      if string.sub(line, submatch["end"] + 1, submatch["end"] + 2) == "]]" then
        return true
      elseif string.sub(line, submatch["end"] + 1, submatch["end"] + 1) == "|" then
        return true
      end
    end
    return false
  end

  local backlink_matches = {}
  local last_path = nil
  local last_note = nil
  local tx, rx = channel.oneshot()

  search.search_async(self.client.dir, "[[" .. tostring(self.note.id), { "--fixed-strings" }, function(match)
    if is_valid_backlink(match) then
      local path = match.path.text
      local src_note
      if path ~= last_path then
        src_note = Note.from_file(path, self.client.dir)
      else
        assert(last_note ~= nil)
        src_note = last_note
      end
      table.insert(
        backlink_matches,
        { note = src_note, line = match.line_number, text = string.gsub(match.lines.text, "\n", "") }
      )
      last_path = path
      last_note = src_note
    end
  end, function(_, _, _)
    tx()
  end)

  rx()

  return backlink_matches
end

---Create a view for the backlinks.
Backlinks.view = function(self)
  async.run(function()
    return self:_gather()
  end, function(backlink_matches)
    vim.schedule(function()
      self:_view(backlink_matches)
    end)
  end)
end

---@param backlink_matches BacklinkMatch[]
Backlinks._view = function(self, backlink_matches)
  -- Clear any existing backlinks buffer.
  wipe_rogue_buffer()

  vim.api.nvim_command("botright " .. tostring(self.client.opts.backlinks.height) .. "split ObsidianBacklinks")

  -- Configure buffer.
  vim.cmd "setlocal nonu"
  vim.cmd "setlocal nornu"
  vim.cmd "setlocal winfixheight"
  vim.api.nvim_buf_set_option(0, "filetype", "ObsidianBacklinks")
  vim.api.nvim_buf_set_option(0, "buftype", "nofile")
  vim.api.nvim_buf_set_option(0, "swapfile", false)
  vim.api.nvim_buf_set_option(0, "buflisted", false)
  vim.api.nvim_buf_set_var(0, "obsidian_vault_dir", tostring(self.client:vault_root()))
  vim.api.nvim_buf_set_var(0, "obsidian_parent_win", self.winnr)
  vim.api.nvim_win_set_option(0, "wrap", self.client.opts.backlinks.wrap)
  vim.api.nvim_win_set_option(0, "spell", false)
  vim.api.nvim_win_set_option(0, "list", false)
  vim.api.nvim_win_set_option(0, "signcolumn", "no")
  vim.api.nvim_win_set_option(0, "foldmethod", "manual")
  vim.api.nvim_win_set_option(0, "foldcolumn", "0")
  vim.api.nvim_win_set_option(0, "foldlevel", 3)
  vim.api.nvim_win_set_option(0, "foldenable", false)

  vim.api.nvim_buf_set_keymap(
    0,
    "n",
    "<CR>",
    [[<cmd>lua require("obsidian.backlinks").open()<CR>]],
    { silent = true, noremap = true, nowait = true }
  )

  vim.wo.foldtext = [[v:lua.require("obsidian.backlinks").foldtext()]]

  vim.api.nvim_buf_set_option(0, "readonly", false)
  vim.api.nvim_buf_set_option(0, "modifiable", true)
  vim.api.nvim_buf_clear_namespace(0, self.client.backlinks_namespace, 0, -1)

  -- Render lines.
  local view_lines = {}
  local highlights = {}
  local folds = {}
  local last_path = nil
  local matches_for_note = 0
  for _, match in pairs(backlink_matches) do
    -- Header for note.
    if match.note.path ~= last_path then
      if last_path ~= nil then
        table.insert(folds, { range = { #view_lines - matches_for_note, #view_lines } })
        table.insert(view_lines, "")
      end
      matches_for_note = 0
      table.insert(view_lines, (" %s"):format(match.note:display_name()))
      table.insert(highlights, { group = "CursorLineNr", line = #view_lines - 1, col_start = 0, col_end = 1 })
      table.insert(highlights, { group = "Directory", line = #view_lines - 1, col_start = 2, col_end = -1 })
    end

    -- Line for backlink within note.
    local display_path = assert(self.client:vault_relative_path(match.note.path))
    local text, ref_indices, ref_strs = search.find_and_replace_refs(match.text)
    local text_start = 4 + display_path:len() + tostring(match.line):len()
    table.insert(view_lines, ("  %s:%s:%s"):format(display_path, match.line, text))

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

    last_path = match.note.path
    matches_for_note = matches_for_note + 1
  end
  table.insert(folds, { range = { #view_lines - matches_for_note, #view_lines } })

  vim.api.nvim_buf_set_lines(0, 0, -1, false, view_lines)

  -- Render highlights.
  for _, hl in pairs(highlights) do
    vim.api.nvim_buf_add_highlight(0, self.client.backlinks_namespace, hl.group, hl.line, hl.col_start, hl.col_end)
  end

  -- Create folds.
  for _, fold in pairs(folds) do
    vim.api.nvim_cmd({ range = fold.range, cmd = "fold" }, {})
  end

  -- Lock the buffer.
  vim.api.nvim_buf_set_option(0, "readonly", true)
  vim.api.nvim_buf_set_option(0, "modifiable", false)
end

Backlinks.open = function()
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
