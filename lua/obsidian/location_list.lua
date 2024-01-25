local abc = require "obsidian.abc"
local Path = require "plenary.path"
local iter = require("obsidian.itertools").iter

---@param bufname string
---
---@return integer|?
---
---@private
local function find_rogue_buffer(bufname)
  for v in iter(vim.api.nvim_list_bufs()) do
    if vim.fn.bufname(v) == bufname then
      return v
    end
  end
  return nil
end

--- Find pre-existing location list buffer, delete its windows then wipe it.
---
---@param bufname string
---
---@private
local function wipe_rogue_buffer(bufname)
  local bn = find_rogue_buffer(bufname)
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

--- Parse path and line number from a line in a location list buffer.
---
---@param line string
---
---@return string|?, string|?
---
---@private
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

---@class obsidian.LocationList : obsidian.ABC
---
---@field client obsidian.Client
---@field bufnr integer
---@field winnr integer
---@field bufname string
---@field namespace string
---@field wrap boolean
---@field height integer
local LocationList = abc.new_class()

--- Create a new LocationList instance.
---
---@param client obsidian.Client
---@param bufnr integer
---@param winnr integer
---@param namespace string
---@param opts obsidian.config.LocationListOpts
---
---@return obsidian.LocationList
LocationList.new = function(client, bufnr, winnr, namespace, opts)
  local self = LocationList.init()
  self.client = client
  self.bufnr = bufnr
  self.winnr = winnr
  self.bufname = vim.api.nvim_buf_get_name(self.bufnr)
  self.namespace = namespace
  self.wrap = opts.wrap
  self.height = opts.height or 10
  return self
end

LocationList._set_buffer_options = function(self)
  vim.cmd "setlocal nonu"
  vim.cmd "setlocal nornu"
  vim.cmd "setlocal winfixheight"

  vim.opt_local.filetype = "ObsidianLocationList"
  vim.opt_local.buftype = "nofile"
  vim.opt_local.swapfile = false
  vim.opt_local.buflisted = false
  vim.opt_local.wrap = self.wrap
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
    [[<cmd>lua require("obsidian.location_list").open_or_fold()<CR>]],
    { silent = true, noremap = true, nowait = true }
  )

  vim.wo.foldtext = [[v:lua.require("obsidian.location_list").foldtext()]]
end

--- Render the location list buffer.
---
---@param lines string[]
---@param folds table[]
---@param highlights table[]
LocationList.render = function(self, lines, folds, highlights)
  -- Save view of current window so we can return focus after.
  local cur_winnr = vim.api.nvim_get_current_win()
  local cur_win_view = vim.fn.winsaveview()

  -- Clear any existing location list buffer.
  wipe_rogue_buffer(self.namespace)

  -- Create namespace (if it doesn't already exist).
  local ns_id = vim.api.nvim_create_namespace(self.namespace)

  -- Open buffer.
  vim.api.nvim_command(
    "botright " .. tostring(self.height) .. "split " .. self.namespace .. " | resize " .. tostring(self.height)
  )

  -- Configure buffer.
  self:_set_buffer_options()

  -- Set buffer lines, folds, highlights.
  vim.opt_local.readonly = false
  vim.opt_local.modifiable = true

  vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)

  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)

  for _, fold in pairs(folds) do
    vim.api.nvim_cmd({ range = fold.range, cmd = "fold" }, {})
  end

  for _, hl in pairs(highlights) do
    vim.api.nvim_buf_add_highlight(0, ns_id, hl.group, hl.line, hl.col_start, hl.col_end)
  end

  -- Lock the buffer.
  vim.opt_local.readonly = true
  vim.opt_local.modifiable = false

  -- Return focus to the previous window and restore view.
  vim.api.nvim_set_current_win(cur_winnr)
  vim.fn.winrestview(cur_win_view) ---@diagnostic disable-line: param-type-mismatch
end

LocationList.open_or_fold = function()
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

LocationList.foldtext = function()
  local foldstart = vim.api.nvim_get_vvar "foldstart"
  local foldend = vim.api.nvim_get_vvar "foldend"
  local num_links = foldend - foldstart

  local line = vim.api.nvim_buf_get_lines(0, foldstart - 1, foldstart, true)[1]

  local match, _ = line:gsub("^ (.+)", " %1 " .. ("(%s link%s)"):format(num_links, num_links > 1 and "s" or ""))
  return match
end

return LocationList
