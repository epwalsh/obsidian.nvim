local fzf = require "fzf-lua"
local fzf_actions = require "fzf-lua.actions"
local entry_to_file = require("fzf-lua.path").entry_to_file

local Path = require "obsidian.path"
local abc = require "obsidian.abc"
local util = require "obsidian.util"
local Picker = require "obsidian.pickers.picker"

---@param prompt_title string|?
---@return string|?
local function get_prompt(prompt_title)
  if not prompt_title then
    return
  else
    return prompt_title .. " ❯ "
  end
end

---@param keymap string
---@return string
local function format_keymap(keymap)
  keymap = string.lower(keymap)
  keymap = util.string_replace(keymap, "<c-", "ctrl-")
  keymap = util.string_replace(keymap, ">", "")
  return keymap
end

---@class obsidian.pickers.FzfPicker : obsidian.Picker
local FzfPicker = abc.new_class({
  ---@diagnostic disable-next-line: unused-local
  __tostring = function(self)
    return "FzfPicker()"
  end,
}, Picker)

---@param opts { callback: fun(path: string)|?, no_default_mappings: boolean|?, selection_mappings: obsidian.PickerMappingTable|? }
local function get_path_actions(opts)
  local actions = {
    default = function(selected, fzf_opts)
      if not opts.no_default_mappings then
        fzf_actions.file_edit_or_qf(selected, fzf_opts)
      end

      if opts.callback then
        local path = entry_to_file(selected[1], fzf_opts).path
        opts.callback(path)
      end
    end,
  }

  if opts.selection_mappings then
    for key, mapping in pairs(opts.selection_mappings) do
      actions[format_keymap(key)] = function(selected, fzf_opts)
        local path = entry_to_file(selected[1], fzf_opts).path
        mapping.callback(path)
      end
    end
  end

  return actions
end

---@param display_to_value_map table<string, any>
---@param opts { callback: fun(path: string)|?, selection_mappings: obsidian.PickerMappingTable|? }
local function get_value_actions(display_to_value_map, opts)
  local actions = {
    default = function(selected)
      if opts.callback and selected and display_to_value_map[selected[1]] then
        opts.callback(display_to_value_map[selected[1]])
      end
    end,
  }

  if opts.selection_mappings then
    for key, mapping in pairs(opts.selection_mappings) do
      actions[format_keymap(key)] = function(selected)
        if selected and display_to_value_map[selected[1]] then
          mapping.callback(display_to_value_map[selected[1]])
        end
      end
    end
  end

  return actions
end

---@param opts obsidian.PickerFindOpts|? Options.
FzfPicker.find_files = function(self, opts)
  opts = opts or {}

  ---@type obsidian.Path
  local dir = opts.dir and Path.new(opts.dir) or self.client.dir

  fzf.files {
    cwd = tostring(dir),
    cmd = table.concat(self:_build_find_cmd(), " "),
    actions = get_path_actions {
      callback = opts.callback,
      no_default_mappings = opts.no_default_mappings,
      selection_mappings = opts.selection_mappings,
    },
    prompt = get_prompt(opts.prompt_title),
  }
end

---@param opts obsidian.PickerGrepOpts|? Options.
FzfPicker.grep = function(self, opts)
  opts = opts and opts or {}

  ---@type obsidian.Path
  local dir = opts.dir and Path:new(opts.dir) or self.client.dir
  local cmd = table.concat(self:_build_grep_cmd(), " ")
  local actions = get_path_actions {
    callback = opts.callback,
    no_default_mappings = opts.no_default_mappings,
    selection_mappings = opts.selection_mappings,
  }

  if opts.query and string.len(opts.query) > 0 then
    fzf.grep {
      cwd = tostring(dir),
      search = opts.query,
      cmd = cmd,
      actions = actions,
      prompt = get_prompt(opts.prompt_title),
    }
  else
    fzf.live_grep {
      cwd = tostring(dir),
      cmd = cmd,
      actions = actions,
      prompt = get_prompt(opts.prompt_title),
    }
  end
end

---@param values string[]|obsidian.PickerEntry[]
---@param opts obsidian.PickerPickOpts|? Options.
---@diagnostic disable-next-line: unused-local
FzfPicker.pick = function(self, values, opts)
  self.calling_bufnr = vim.api.nvim_get_current_buf()

  opts = opts or {}

  ---@type table<string, any>
  local display_to_value_map = {}

  ---@type string[]
  local entries = {}
  for _, value in ipairs(values) do
    if type(value) == "string" then
      display_to_value_map[value] = value
      entries[#entries + 1] = value
    elseif value.valid ~= false then
      local display = self:_make_display(value)
      display_to_value_map[display] = value.value
      entries[#entries + 1] = display
    end
  end

  fzf.fzf_exec(entries, {
    prompt = get_prompt(opts.prompt_title),
    actions = get_value_actions(display_to_value_map, {
      callback = opts.callback,
      selection_mappings = opts.selection_mappings,
    }),
  })
end

return FzfPicker
