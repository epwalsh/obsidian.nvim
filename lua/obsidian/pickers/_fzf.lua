local Path = require "plenary.path"
local fzf = require "fzf-lua"
local fzf_actions = require "fzf-lua.actions"
local entry_to_file = require("fzf-lua.path").entry_to_file
local abc = require "obsidian.abc"
local util = require "obsidian.util"
local Picker = require "obsidian.pickers.picker"

---@param prompt_title string|?
---@return string|?
local function get_prompt(prompt_title)
  if not prompt_title then
    return
  else
    return prompt_title .. "❯"
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
local FzfPicker = abc.new_class({}, Picker)

---@param opts { callback: fun(path: string)|?, no_default_mappings: boolean|?, dir: string|Path|? }
FzfPicker.get_actions = function(self, opts)
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

  if opts.no_default_mappings then
    return actions
  end

  ---@type string|?
  local keymap

  keymap = self.client.opts.picker.mappings.insert_link
  if keymap then
    actions[format_keymap(keymap)] = function(selected, fzf_opts)
      local path = entry_to_file(selected[1], fzf_opts).path
      local note = require("obsidian").Note.from_file(path, self.client.dir)
      local link = self.client:format_link(note, {})
      vim.api.nvim_put({ link }, "", false, true)
    end
  end

  return actions
end

---@param opts { prompt_title: string|?, callback: fun(path: string)|?, no_default_mappings: boolean|?, dir: string|Path|? }|?
FzfPicker.find_files = function(self, opts)
  opts = opts and opts or {}

  ---@type Path
  local dir = opts.dir and Path:new(opts.dir) or self.client.dir

  fzf.files {
    cwd = tostring(dir),
    cmd = table.concat(self:_build_find_cmd(), " "),
    actions = self:get_actions(opts),
    prompt = get_prompt(opts.prompt_title),
  }
end

---@param opts { prompt_title: string|?, dir: string|Path|?, query: string|?, callback: fun(path: string)|?, no_default_mappings: boolean|? }|?
FzfPicker.grep = function(self, opts)
  opts = opts and opts or {}

  ---@type Path
  local dir = opts.dir and Path:new(opts.dir) or self.client.dir

  local cmd = table.concat(self:_build_grep_cmd(), " ")

  if opts.query and string.len(opts.query) > 0 then
    fzf.grep {
      cwd = tostring(dir),
      search = opts.query,
      cmd = cmd,
      actions = self:get_actions(opts),
      prompt = get_prompt(opts.prompt_title),
    }
  else
    fzf.live_grep {
      cwd = tostring(dir),
      cmd = cmd,
      actions = self:get_actions(opts),
      prompt = get_prompt(opts.prompt_title),
    }
  end
end

---@param values string[]|obsidian.PickerEntry[]
---@param opts { prompt_title: string|?, callback: fun(value: any)|? }|?
---@diagnostic disable-next-line: unused-local
FzfPicker.pick = function(self, values, opts)
  opts = opts and opts or {}

  ---@type table<string, any>
  local display_to_value_map = {}

  ---@type string[]
  local entries = {}
  for _, value in ipairs(values) do
    if type(value) == "string" then
      display_to_value_map[value] = value
      entries[#entries + 1] = value
    elseif value.valid ~= false then
      display_to_value_map[value.display] = value.value
      entries[#entries + 1] = value.display
    end
  end

  fzf.fzf_exec(entries, {
    prompt = get_prompt(opts.prompt_title),
    actions = {
      default = function(selected)
        if opts.callback then
          opts.callback(display_to_value_map[selected[1]])
        end
      end,
    },
  })
end

return FzfPicker
