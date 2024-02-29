local telescope = require "telescope.builtin"
local telescope_actions = require "telescope.actions"
local actions_state = require "telescope.actions.state"

local Path = require "obsidian.path"
local abc = require "obsidian.abc"
local Picker = require "obsidian.pickers.picker"

---@class obsidian.pickers.TelescopePicker : obsidian.Picker
local TelescopePicker = abc.new_class({
  ---@diagnostic disable-next-line: unused-local
  __tostring = function(self)
    return "TelescopePicker()"
  end,
}, Picker)

---@return table|?
local function get_entry_and_close(prompt_bufnr)
  local entry = actions_state.get_selected_entry()
  if entry then
    telescope_actions.close(prompt_bufnr)
  end
  return entry
end

---@param initial_query string|?
---@return string|?
local function get_query_and_close(prompt_bufnr, initial_query)
  local query = actions_state.get_current_line()
  if not query or string.len(query) == 0 then
    query = initial_query
  end
  if query and string.len(query) > 0 then
    telescope_actions.close(prompt_bufnr)
    return query
  else
    return nil
  end
end

---@param map table
---@param opts { callback: fun(path: string)|?, query_mappings: obsidian.PickerMappingTable|?, selection_mappings: obsidian.PickerMappingTable|?, initial_query: string|? }
local function attach_path_picker_mappings(map, opts)
  -- Docs for telescope actions:
  -- https://github.com/nvim-telescope/telescope.nvim/blob/master/lua/telescope/actions/init.lua

  if opts.query_mappings then
    for key, mapping in pairs(opts.query_mappings) do
      map({ "i", "n" }, key, function(prompt_bufnr)
        local query = get_query_and_close(prompt_bufnr, opts.initial_query)
        if query then
          mapping.callback(query)
        end
      end)
    end
  end

  if opts.selection_mappings then
    for key, mapping in pairs(opts.selection_mappings) do
      map({ "i", "n" }, key, function(prompt_bufnr)
        local entry = get_entry_and_close(prompt_bufnr)
        if entry then
          mapping.callback(entry.path)
        end
      end)
    end
  end

  if opts.callback then
    map({ "i", "n" }, "<CR>", function(prompt_bufnr)
      local entry = get_entry_and_close(prompt_bufnr)
      if entry then
        opts.callback(entry.path)
      end
    end)
  end
end

---@param map table
---@param opts { callback: fun(item: any)|?, query_mappings: obsidian.PickerMappingTable|?, selection_mappings: obsidian.PickerMappingTable|? }
local function attach_value_picker_mappings(map, opts)
  if opts.query_mappings then
    for key, mapping in pairs(opts.query_mappings) do
      map({ "i", "n" }, key, function(prompt_bufnr)
        local query = get_query_and_close(prompt_bufnr)
        if query then
          mapping.callback(query)
        end
      end)
    end
  end

  if opts.selection_mappings then
    for key, mapping in pairs(opts.selection_mappings) do
      map({ "i", "n" }, key, function(prompt_bufnr)
        local entry = get_entry_and_close(prompt_bufnr)
        if entry then
          mapping.callback(entry.value)
        elseif mapping.fallback_to_query then
          local query = get_query_and_close(prompt_bufnr)
          if query then
            mapping.callback(query)
          end
        end
      end)
    end
  end

  if opts.callback then
    map({ "i", "n" }, "<CR>", function(prompt_bufnr)
      local entry = get_entry_and_close(prompt_bufnr)
      if entry then
        opts.callback(entry.value)
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
    attach_mappings = function(_, map)
      attach_path_picker_mappings(
        map,
        { callback = opts.callback, query_mappings = opts.query_mappings, selection_mappings = opts.selection_mappings }
      )
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
    attach_path_picker_mappings(map, {
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
  local conf = require("telescope.config").values
  local make_entry = require "telescope.make_entry"

  opts = opts and opts or {}

  local picker_opts = {
    attach_mappings = function(_, map)
      attach_value_picker_mappings(
        map,
        { callback = opts.callback, query_mappings = opts.query_mappings, selection_mappings = opts.selection_mappings }
      )
      return true
    end,
  }

  local make_entry_from_string = make_entry.gen_from_string(picker_opts)

  local displayer = function(entry)
    return self:_make_display(entry.raw)
  end

  local prompt_title = self:_build_prompt {
    prompt_title = opts.prompt_title,
    query_mappings = opts.query_mappings,
    selection_mappings = opts.selection_mappings,
  }

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
      sorter = conf.generic_sorter(picker_opts),
      previewer = conf.grep_previewer(picker_opts),
    })
    :find()
end

return TelescopePicker
