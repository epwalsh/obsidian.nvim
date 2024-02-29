local mini_pick = require "mini.pick"

local Path = require "obsidian.path"
local abc = require "obsidian.abc"
local Picker = require "obsidian.pickers.picker"

---@param entry string
---@return string
local function clean_path(entry)
  local path_end = assert(string.find(entry, ":", 1, true))
  return string.sub(entry, 1, path_end - 1)
end

---@class obsidian.pickers.MiniPicker : obsidian.Picker
local MiniPicker = abc.new_class({
  ---@diagnostic disable-next-line: unused-local
  __tostring = function(self)
    return "MiniPicker()"
  end,
}, Picker)

---@param opts obsidian.PickerFindOpts|? Options.
MiniPicker.find_files = function(self, opts)
  opts = opts or {}

  ---@type obsidian.Path
  local dir = opts.dir and Path:new(opts.dir) or self.client.dir

  local path = mini_pick.builtin.cli({
    command = self:_build_find_cmd(),
  }, {
    source = {
      name = opts.prompt_title,
      cwd = tostring(dir),
      choose = function(path)
        if not opts.no_default_mappings then
          mini_pick.default_choose(path)
        end
      end,
    },
  })

  if path and opts.callback then
    opts.callback(tostring(dir / path))
  end
end

---@param opts obsidian.PickerGrepOpts|? Options.
MiniPicker.grep = function(self, opts)
  opts = opts and opts or {}

  ---@type obsidian.Path
  local dir = opts.dir and Path:new(opts.dir) or self.client.dir

  local pick_opts = {
    source = {
      name = opts.prompt_title,
      cwd = tostring(dir),
      choose = function(path)
        if not opts.no_default_mappings then
          mini_pick.default_choose(path)
        end
      end,
    },
  }

  ---@type string|?
  local result
  if opts.query and string.len(opts.query) > 0 then
    result = mini_pick.builtin.grep({ pattern = opts.query }, pick_opts)
  else
    result = mini_pick.builtin.grep_live({}, pick_opts)
  end

  if result and opts.callback then
    local path = clean_path(result)
    opts.callback(tostring(dir / path))
  end
end

---@param values string[]|obsidian.PickerEntry[]
---@param opts obsidian.PickerPickOpts|? Options.
---@diagnostic disable-next-line: unused-local
MiniPicker.pick = function(self, values, opts)
  self.calling_bufnr = vim.api.nvim_get_current_buf()

  opts = opts and opts or {}

  local entries = {}
  for _, value in ipairs(values) do
    if type(value) == "string" then
      entries[#entries + 1] = value
    elseif value.valid ~= false then
      entries[#entries + 1] = {
        value = value.value,
        text = self:_make_display(value),
        path = value.filename,
        lnum = value.lnum,
        col = value.col,
      }
    end
  end

  local entry = mini_pick.start {
    source = {
      name = opts.prompt_title,
      items = entries,
      choose = function() end,
    },
  }

  if entry and opts.callback then
    if type(entry) == "string" then
      opts.callback(entry)
    else
      opts.callback(entry.value)
    end
  end
end

return MiniPicker
