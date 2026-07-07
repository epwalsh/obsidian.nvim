local telescope = require "telescope.builtin"
local telescope_actions = require "telescope.actions"
local actions_state = require "telescope.actions.state"

local Path = require "obsidian.path"
local abc = require "obsidian.abc"
local Picker = require "obsidian.pickers.picker"
local log = require "obsidian.log"

---@class obsidian.pickers.TelescopePicker : obsidian.Picker
local TelescopePicker = abc.new_class({
  ---@diagnostic disable-next-line: unused-local
  __tostring = function(self)
    return "TelescopePicker()"
  end,
}, Picker)

---@param prompt_bufnr integer
---@param keep_open boolean|?
---@return table|?
local function get_entry(prompt_bufnr, keep_open)
  local entry = actions_state.get_selected_entry()
  if entry and not keep_open then
    telescope_actions.close(prompt_bufnr)
  end
  return entry
end

---@param prompt_bufnr integer
---@param keep_open boolean|?
---@param allow_multiple boolean|?
---@return table[]|?
local function get_selected(prompt_bufnr, keep_open, allow_multiple)
  local picker = actions_state.get_current_picker(prompt_bufnr)
  local entries = picker:get_multi_selection()
  if entries and #entries > 0 then
    if #entries > 1 and not allow_multiple then
      log.err "This mapping does not allow multiple entries"
      return
    end

    if not keep_open then
      telescope_actions.close(prompt_bufnr)
    end

    return entries
  else
    local entry = get_entry(prompt_bufnr, keep_open)

    if entry then
      return { entry }
    end
  end
end

---@param prompt_bufnr integer
---@param keep_open boolean|?
---@param initial_query string|?
---@return string|?
local function get_query(prompt_bufnr, keep_open, initial_query)
  local query = actions_state.get_current_line()
  if not query or string.len(query) == 0 then
    query = initial_query
  end
  if query and string.len(query) > 0 then
    if not keep_open then
      telescope_actions.close(prompt_bufnr)
    end
    return query
  else
    return nil
  end
end

---@param opts { entry_key: string|?, callback: fun(path: string)|?, allow_multiple: boolean|?, query_mappings: obsidian.PickerMappingTable|?, selection_mappings: obsidian.PickerMappingTable|?, initial_query: string|? }
local function attach_picker_mappings(map, opts)
  -- Docs for telescope actions:
  -- https://github.com/nvim-telescope/telescope.nvim/blob/master/lua/telescope/actions/init.lua

  local function entry_to_value(entry)
    if opts.entry_key then
      return entry[opts.entry_key]
    else
      return entry
    end
  end

  if opts.query_mappings then
    for key, mapping in pairs(opts.query_mappings) do
      map({ "i", "n" }, key, function(prompt_bufnr)
        local query = get_query(prompt_bufnr, false, opts.initial_query)
        if query then
          mapping.callback(query)
        end
      end)
    end
  end

  if opts.selection_mappings then
    for key, mapping in pairs(opts.selection_mappings) do
      map({ "i", "n" }, key, function(prompt_bufnr)
        local entries = get_selected(prompt_bufnr, mapping.keep_open, mapping.allow_multiple)
        if entries then
          local values = vim.tbl_map(entry_to_value, entries)
          mapping.callback(unpack(values))
        elseif mapping.fallback_to_query then
          local query = get_query(prompt_bufnr, mapping.keep_open)
          if query then
            mapping.callback(query)
          end
        end
      end)
    end
  end

  if opts.callback then
    map({ "i", "n" }, "<CR>", function(prompt_bufnr)
      local entries = get_selected(prompt_bufnr, false, opts.allow_multiple)
      if entries then
        local values = vim.tbl_map(entry_to_value, entries)
        opts.callback(unpack(values))
      end
    end)
  end
end

---@param opts obsidian.PickerFindOpts|? Options.
TelescopePicker.find_files = function(self, opts)
  opts = opts or {}

  local prompt_title = self:_build_prompt {
    prompt_title = opts.prompt_title,
    query_mappings = opts.query_mappings,
    selection_mappings = opts.selection_mappings,
  }

  telescope.find_files {
    prompt_title = prompt_title,
    cwd = opts.dir and tostring(opts.dir) or tostring(self.client.dir),
    find_command = self:_build_find_cmd(),
    sorter = require("telescope.sorters").fuzzy_with_index_bias(),
    attach_mappings = function(_, map)
      attach_picker_mappings(map, {
        entry_key = "path",
        callback = opts.callback,
        query_mappings = opts.query_mappings,
        selection_mappings = opts.selection_mappings,
      })
      return true
    end,
  }
end

---@param opts obsidian.PickerGrepOpts|? Options.
TelescopePicker.grep = function(self, opts)
  opts = opts or {}

  local cwd = opts.dir and Path:new(opts.dir) or self.client.dir

  local prompt_title = self:_build_prompt {
    prompt_title = opts.prompt_title,
    query_mappings = opts.query_mappings,
    selection_mappings = opts.selection_mappings,
  }

  local attach_mappings = function(_, map)
    attach_picker_mappings(map, {
      entry_key = "path",
      callback = opts.callback,
      query_mappings = opts.query_mappings,
      selection_mappings = opts.selection_mappings,
      initial_query = opts.query,
    })
    return true
  end

  if opts.query and string.len(opts.query) > 0 then
    telescope.grep_string {
      prompt_title = prompt_title,
      cwd = tostring(cwd),
      vimgrep_arguments = self:_build_grep_cmd(),
      search = opts.query,
      attach_mappings = attach_mappings,
    }
  else
    telescope.live_grep {
      prompt_title = prompt_title,
      cwd = tostring(cwd),
      vimgrep_arguments = self:_build_grep_cmd(),
      attach_mappings = attach_mappings,
    }
  end
end

---@param values string[]|obsidian.PickerEntry[]
---@param opts obsidian.PickerPickOpts|? Options.
TelescopePicker.pick = function(self, values, opts)
  local pickers = require "telescope.pickers"
  local finders = require "telescope.finders"
  local conf = require "telescope.config"
  local make_entry = require "telescope.make_entry"

  self.calling_bufnr = vim.api.nvim_get_current_buf()

  opts = opts and opts or {}

  local picker_opts = {
    attach_mappings = function(_, map)
      attach_picker_mappings(map, {
        entry_key = "value",
        callback = opts.callback,
        allow_multiple = opts.allow_multiple,
        query_mappings = opts.query_mappings,
        selection_mappings = opts.selection_mappings,
      })
      return true
    end,
  }

  local displayer = function(entry)
    return self:_make_display(entry.raw)
  end

  local prompt_title = self:_build_prompt {
    prompt_title = opts.prompt_title,
    query_mappings = opts.query_mappings,
    selection_mappings = opts.selection_mappings,
  }

  local previewer
  if type(values[1]) == "table" then
    previewer = conf.values.grep_previewer(picker_opts)
    -- Get theme to use.
    if conf.pickers then
      for _, picker_name in ipairs { "grep_string", "live_grep", "find_files" } do
        local picker_conf = conf.pickers[picker_name]
        if picker_conf and picker_conf.theme then
          picker_opts =
            vim.tbl_extend("force", picker_opts, require("telescope.themes")["get_" .. picker_conf.theme] {})
          break
        end
      end
    end
  end

  local make_entry_from_string = make_entry.gen_from_string(picker_opts)

  pickers
    .new(picker_opts, {
      prompt_title = prompt_title,
      finder = finders.new_table {
        results = values,
        entry_maker = function(v)
          if type(v) == "string" then
            return make_entry_from_string(v)
          else
            local ordinal = v.ordinal
            if ordinal == nil then
              ordinal = ""
              if type(v.display) == "string" then
                ordinal = ordinal .. v.display
              end
              if v.filename ~= nil then
                ordinal = ordinal .. " " .. v.filename
              end
            end

            return {
              value = v.value,
              display = displayer,
              ordinal = ordinal,
              filename = v.filename,
              valid = v.valid,
              lnum = v.lnum,
              col = v.col,
              raw = v,
            }
          end
        end,
      },
      sorter = conf.values.generic_sorter(picker_opts),
      previewer = previewer,
    })
    :find()
end

return TelescopePicker
