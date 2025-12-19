local Path = require "obsidian.path"
local abc = require "obsidian.abc"
local log = require "obsidian.log"
local Picker = require "obsidian.pickers.picker"

---@class obsidian.pickers.SnacksPicker : obsidian.Picker
local SnacksPicker = abc.new_class({
  ---@diagnostic disable-next-line: unused-local
  __tostring = function(self)
    return "SnacksPicker()"
  end,
}, Picker)

---Convert obsidian keymap format to snacks format
---@param keymap string
---@return string
local function format_keymap(keymap)
  -- Snacks uses the same format as vim keymaps, so we can use it directly
  -- But we need to handle some special cases
  return keymap
end

---Build win configuration with keymaps for snacks picker from obsidian mappings
---@param opts { query_mappings: obsidian.PickerMappingTable|?, selection_mappings: obsidian.PickerMappingTable|? }
---@param calling_bufnr integer
---@return table
local function build_win_config(opts, calling_bufnr)
  local win_opts = {
    keys = {},
  }

  -- Add query mappings (actions that use the query text)
  if opts.query_mappings then
    for key, mapping in pairs(opts.query_mappings) do
      local formatted_key = format_keymap(key)
      win_opts.keys[formatted_key] = function(picker)
        -- Get the current query text from the picker
        local query = picker.input:get()
        vim.api.nvim_set_current_buf(calling_bufnr)
        mapping.callback(query)
        if not mapping.keep_open then
          picker:close()
        end
      end
    end
  end

  -- Add selection mappings (actions that use selected items)
  if opts.selection_mappings then
    for key, mapping in pairs(opts.selection_mappings) do
      local formatted_key = format_keymap(key)
      win_opts.keys[formatted_key] = function(picker)
        local current = picker.list:current()
        if not current then
          if mapping.fallback_to_query then
            -- Fallback to query if no selection
            local query = picker.input:get()
            vim.api.nvim_set_current_buf(calling_bufnr)
            mapping.callback(query)
            if not mapping.keep_open then
              picker:close()
            end
          end
          return
        end

        -- For multi-select, get all marked items
        local items = { current }
        if mapping.allow_multiple then
          items = picker.list:selected() or { current }
        end

        -- Check if multiple selections are allowed
        if #items > 1 and not mapping.allow_multiple then
          log.err "This mapping does not allow multiple entries"
          return
        end

        -- Extract values from items
        local values = vim.tbl_map(function(item)
          return item.value or item.file or item.text
        end, items)

        vim.api.nvim_set_current_buf(calling_bufnr)
        mapping.callback(unpack(values))

        if not mapping.keep_open then
          picker:close()
        end
      end
    end
  end

  return win_opts
end

---@param opts obsidian.PickerFindOpts|? Options.
SnacksPicker.find_files = function(self, opts)
  opts = opts or {}

  local ok, snacks = pcall(require, "snacks")
  if not ok or not snacks.picker then
    log.err "snacks.nvim picker not available"
    return
  end

  ---@type obsidian.Path
  local dir = opts.dir and Path.new(opts.dir) or self.client.dir

  local calling_bufnr = vim.api.nvim_get_current_buf()

  local win_opts = build_win_config({
    query_mappings = opts.query_mappings,
    selection_mappings = opts.selection_mappings,
  }, calling_bufnr)

  local picker_opts = {
    source = "files",
    cwd = tostring(dir),
    cmd = table.concat(self:_build_find_cmd(), " "),
    prompt = opts.prompt_title or "Files",
    confirm = function(picker, item)
      if not item then
        return
      end
      picker:close()
      if not opts.no_default_mappings then
        vim.cmd("edit " .. vim.fn.fnameescape(item.file))
      end
      if opts.callback then
        opts.callback(item.file)
      end
    end,
  }

  -- Merge custom keymaps into picker opts
  if win_opts.keys and next(win_opts.keys) then
    picker_opts.win = picker_opts.win or {}
    picker_opts.win.keys = win_opts.keys
  end

  snacks.picker(picker_opts)
end

---@param opts obsidian.PickerGrepOpts|? Options.
SnacksPicker.grep = function(self, opts)
  opts = opts or {}

  local ok, snacks = pcall(require, "snacks")
  if not ok or not snacks.picker then
    log.err "snacks.nvim picker not available"
    return
  end

  ---@type obsidian.Path
  local dir = opts.dir and Path.new(opts.dir) or self.client.dir

  local calling_bufnr = vim.api.nvim_get_current_buf()

  local win_opts = build_win_config({
    query_mappings = opts.query_mappings,
    selection_mappings = opts.selection_mappings,
  }, calling_bufnr)

  local picker_opts = {
    source = "grep",
    cwd = tostring(dir),
    cmd = table.concat(self:_build_grep_cmd(), " "),
    prompt = opts.prompt_title or "Grep",
    confirm = function(picker, item)
      if not item then
        return
      end
      picker:close()
      if not opts.no_default_mappings then
        vim.cmd("edit " .. vim.fn.fnameescape(item.file))
        if item.pos then
          vim.api.nvim_win_set_cursor(0, { item.pos[1], item.pos[2] - 1 })
        end
      end
      if opts.callback then
        opts.callback(item.file)
      end
    end,
  }

  if opts.query and string.len(opts.query) > 0 then
    picker_opts.search = opts.query
  end

  -- Merge custom keymaps into picker opts
  if win_opts.keys and next(win_opts.keys) then
    picker_opts.win = picker_opts.win or {}
    picker_opts.win.keys = win_opts.keys
  end

  snacks.picker(picker_opts)
end

---@param values string[]|obsidian.PickerEntry[]
---@param opts obsidian.PickerPickOpts|? Options.
SnacksPicker.pick = function(self, values, opts)
  self.calling_bufnr = vim.api.nvim_get_current_buf()

  opts = opts or {}

  local ok, snacks = pcall(require, "snacks")
  if not ok or not snacks.picker then
    log.err "snacks.nvim picker not available"
    return
  end

  local calling_bufnr = self.calling_bufnr

  -- Convert values to snacks items format
  local items = {}
  for _, value in ipairs(values) do
    if type(value) == "string" then
      items[#items + 1] = {
        text = value,
        value = value,
      }
    elseif value.valid ~= false then
      local display = self:_make_display(value)
      items[#items + 1] = {
        text = display,
        value = value.value,
        file = value.filename,
        pos = value.lnum and { value.lnum, value.col or 1 } or nil,
      }
    end
  end

  local win_opts = build_win_config({
    query_mappings = opts.query_mappings,
    selection_mappings = opts.selection_mappings,
  }, calling_bufnr)

  local picker_opts = {
    prompt = opts.prompt_title or "Pick",
    items = items,
    confirm = function(picker, item)
      if not item then
        return
      end

      local selected_items = { item }
      if opts.allow_multiple then
        selected_items = picker.list:selected() or { item }
      end

      picker:close()

      if opts.callback then
        local values_list = vim.tbl_map(function(i)
          return i.value
        end, selected_items)
        opts.callback(unpack(values_list))
      end
    end,
  }

  -- Merge custom keymaps into picker opts
  if win_opts.keys and next(win_opts.keys) then
    picker_opts.win = picker_opts.win or {}
    picker_opts.win.keys = win_opts.keys
  end

  snacks.picker(picker_opts)
end

return SnacksPicker
