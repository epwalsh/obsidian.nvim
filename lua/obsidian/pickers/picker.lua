local abc = require "obsidian.abc"
local log = require "obsidian.log"

---@class obsidian.Picker : obsidian.ABC
---
---@field client obsidian.Client
local Picker = abc.new_class()

Picker.new = function(client)
  local self = Picker.init()
  self.client = client
  return self
end

---@param opts { prompt_title: string|?, callback: fun(path: string)|?, no_default_mappings: boolean|?, dir: string|Path|? }|?
---@diagnostic disable-next-line: unused-local
Picker.find_files = function(self, opts)
  error "not implemented"
end

--- Find notes.
---
---@param opts { prompt_title: string|?, callback: fun(path: string)|? }|?
Picker.find_notes = function(self, opts)
  opts = opts and opts or {}
  return self:find_files { prompt_title = opts.prompt_title, callback = opts.callback }
end

--- Find templates.
---
---@param opts { callback: fun(path: string) }
Picker.find_templates = function(self, opts)
  local templates_dir = self.client:templates_dir()

  if templates_dir == nil then
    log.err "Templates folder is not defined or does not exist"
    return
  end

  return self:find_files {
    prompt_title = "Templates",
    callback = opts.callback,
    dir = templates_dir,
    no_default_mappings = true,
  }
end

--- Grep for a string.
---
---@param opts { prompt_title: string|?, dir: string|Path|?, query: string|?, callback: fun(path: string)|?, no_default_mappings: boolean|? }|?
---@diagnostic disable-next-line: unused-local
Picker.grep = function(self, opts)
  error "not implemented"
end

---@class obsidian.PickerEntry
---
---@field value any
---@field display string
---@field ordinal string
---@field filename string|?
---@field valid boolean|?
---@field lnum integer|?
---@field col integer|?

--- Picker from a list of values.
---
---@param values string[]|obsidian.PickerEntry[]
---@param opts { prompt_title: string|?, callback: fun(value: any)|? }|?
---@diagnostic disable-next-line: unused-local
Picker.pick = function(self, values, opts)
  error "not implemented"
end

---@return string[]
Picker._build_find_cmd = function(self)
  local search = require "obsidian.search"
  local search_opts =
    search.SearchOpts.from_tbl { sort_by = self.client.opts.sort_by, sort_reversed = self.client.opts.sort_reversed }
  return search.build_find_cmd(".", nil, search_opts)
end

Picker._build_grep_cmd = function(self)
  local search = require "obsidian.search"
  local search_opts = search.SearchOpts.from_tbl {
    sort_by = self.client.opts.sort_by,
    sort_reversed = self.client.opts.sort_reversed,
    smart_case = true,
    fixed_strings = true,
  }
  return search.build_grep_cmd(search_opts)
end

return Picker
