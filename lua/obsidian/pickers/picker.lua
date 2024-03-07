local abc = require "obsidian.abc"
local log = require "obsidian.log"
local util = require "obsidian.util"
local strings = require "plenary.strings"
local Note = require "obsidian.note"

---@class obsidian.Picker : obsidian.ABC
---
---@field client obsidian.Client
---@field calling_bufnr integer
local Picker = abc.new_class()

Picker.new = function(client)
  local self = Picker.init()
  self.client = client
  self.calling_bufnr = vim.api.nvim_get_current_buf()
  return self
end

-------------------------------------------------------------------
--- Abstract methods that need to be implemented by subclasses. ---
-------------------------------------------------------------------

---@class obsidian.PickerMappingOpts
---
---@field desc string
---@field callback fun(...)
---@field fallback_to_query boolean|?
---@field keep_open boolean|?
---@field allow_multiple boolean|?

---@alias obsidian.PickerMappingTable table<string, obsidian.PickerMappingOpts>

---@class obsidian.PickerFindOpts
---
---@field prompt_title string|?
---@field dir string|obsidian.Path|?
---@field callback fun(path: string)|?
---@field no_default_mappings boolean|?
---@field query_mappings obsidian.PickerMappingTable|?
---@field selection_mappings obsidian.PickerMappingTable|?

--- Find files in a directory.
---
---@param opts obsidian.PickerFindOpts|? Options.
---
--- Options:
---  `prompt_title`: Title for the prompt window.
---  `dir`: Directory to search in.
---  `callback`: Callback to run with the selected entry.
---  `no_default_mappings`: Don't apply picker's default mappings.
---  `query_mappings`: Mappings that run with the query prompt.
---  `selection_mappings`: Mappings that run with the current selection.
---
---@diagnostic disable-next-line: unused-local
Picker.find_files = function(self, opts)
  error "not implemented"
end

---@class obsidian.PickerGrepOpts
---
---@field prompt_title string|?
---@field dir string|obsidian.Path|?
---@field query string|?
---@field callback fun(path: string)|?
---@field no_default_mappings boolean|?
---@field query_mappings obsidian.PickerMappingTable
---@field selection_mappings obsidian.PickerMappingTable

--- Grep for a string.
---
---@param opts obsidian.PickerGrepOpts|? Options.
---
--- Options:
---  `prompt_title`: Title for the prompt window.
---  `dir`: Directory to search in.
---  `query`: Initial query to grep for.
---  `callback`: Callback to run with the selected path.
---  `no_default_mappings`: Don't apply picker's default mappings.
---  `query_mappings`: Mappings that run with the query prompt.
---  `selection_mappings`: Mappings that run with the current selection.
---
---@diagnostic disable-next-line: unused-local
Picker.grep = function(self, opts)
  error "not implemented"
end

---@class obsidian.PickerEntry
---
---@field value any
---@field ordinal string|?
---@field display string|?
---@field filename string|?
---@field valid boolean|?
---@field lnum integer|?
---@field col integer|?
---@field icon string|?
---@field icon_hl string|?

---@class obsidian.PickerPickOpts
---
---@field prompt_title string|?
---@field callback fun(value: any, ...: any)|?
---@field allow_multiple boolean|?
---@field query_mappings obsidian.PickerMappingTable|?
---@field selection_mappings obsidian.PickerMappingTable|?

--- Pick from a list of items.
---
---@param values string[]|obsidian.PickerEntry[] Items to pick from.
---@param opts obsidian.PickerPickOpts|? Options.
---
--- Options:
---  `prompt_title`: Title for the prompt window.
---  `callback`: Callback to run with the selected item(s).
---  `allow_multiple`: Allow multiple selections to pass to the callback.
---  `query_mappings`: Mappings that run with the query prompt.
---  `selection_mappings`: Mappings that run with the current selection.
---
---@diagnostic disable-next-line: unused-local
Picker.pick = function(self, values, opts)
  error "not implemented"
end

------------------------------------------------------------------
--- Concrete methods with a default implementation subclasses. ---
------------------------------------------------------------------

--- Find notes by filename.
---
---@param opts { prompt_title: string|?, callback: fun(path: string)|?, no_default_mappings: boolean|? }|? Options.
---
--- Options:
---  `prompt_title`: Title for the prompt window.
---  `callback`: Callback to run with the selected note path.
---  `no_default_mappings`: Don't apply picker's default mappings.
Picker.find_notes = function(self, opts)
  self.calling_bufnr = vim.api.nvim_get_current_buf()

  opts = opts or {}

  local query_mappings
  local selection_mappings
  if not opts.no_default_mappings then
    query_mappings = self:_note_query_mappings()
    selection_mappings = self:_note_selection_mappings()
  end

  return self:find_files {
    prompt_title = opts.prompt_title or "Notes",
    dir = self.client.dir,
    callback = opts.callback,
    no_default_mappings = opts.no_default_mappings,
    query_mappings = query_mappings,
    selection_mappings = selection_mappings,
  }
end

--- Find templates by filename.
---
---@param opts { prompt_title: string|?, callback: fun(path: string) }|? Options.
---
--- Options:
---  `callback`: Callback to run with the selected template path.
Picker.find_templates = function(self, opts)
  self.calling_bufnr = vim.api.nvim_get_current_buf()

  opts = opts or {}

  local templates_dir = self.client:templates_dir()

  if templates_dir == nil then
    log.err "Templates folder is not defined or does not exist"
    return
  end

  return self:find_files {
    prompt_title = opts.prompt_title or "Templates",
    callback = opts.callback,
    dir = templates_dir,
    no_default_mappings = true,
  }
end

--- Grep search in notes.
---
---@param opts { prompt_title: string|?, query: string|?, callback: fun(path: string)|?, no_default_mappings: boolean|? }|? Options.
---
--- Options:
---  `prompt_title`: Title for the prompt window.
---  `query`: Initial query to grep for.
---  `callback`: Callback to run with the selected path.
---  `no_default_mappings`: Don't apply picker's default mappings.
Picker.grep_notes = function(self, opts)
  self.calling_bufnr = vim.api.nvim_get_current_buf()

  opts = opts or {}

  local query_mappings
  local selection_mappings
  if not opts.no_default_mappings then
    query_mappings = self:_note_query_mappings()
    selection_mappings = self:_note_selection_mappings()
  end

  self:grep {
    prompt_title = opts.prompt_title or "Grep notes",
    dir = self.client.dir,
    query = opts.query,
    callback = opts.callback,
    no_default_mappings = opts.no_default_mappings,
    query_mappings = query_mappings,
    selection_mappings = selection_mappings,
  }
end

--- Open picker with a list of notes.
---
---@param notes obsidian.Note[]
---@param opts { prompt_title: string|?, callback: fun(note: obsidian.Note, ...: obsidian.Note), allow_multiple: boolean|?, no_default_mappings: boolean|? }|? Options.
---
--- Options:
---  `prompt_title`: Title for the prompt window.
---  `callback`: Callback to run with the selected note(s).
---  `allow_multiple`: Allow multiple selections to pass to the callback.
---  `no_default_mappings`: Don't apply picker's default mappings.
Picker.pick_note = function(self, notes, opts)
  self.calling_bufnr = vim.api.nvim_get_current_buf()

  opts = opts or {}

  local query_mappings
  local selection_mappings
  if not opts.no_default_mappings then
    query_mappings = self:_note_query_mappings()
    selection_mappings = self:_note_selection_mappings()
  end

  -- Launch picker with results.
  ---@type obsidian.PickerEntry[]
  local entries = {}
  for _, note in ipairs(notes) do
    assert(note.path)
    local rel_path = tostring(assert(self.client:vault_relative_path(note.path, { strict = true })))
    local display_name = note:display_name()
    entries[#entries + 1] = {
      value = note,
      display = display_name,
      ordinal = rel_path .. " " .. display_name,
      filename = tostring(note.path),
    }
  end

  self:pick(entries, {
    prompt_title = opts.prompt_title or "Notes",
    callback = opts.callback,
    allow_multiple = opts.allow_multiple,
    no_default_mappings = opts.no_default_mappings,
    query_mappings = query_mappings,
    selection_mappings = selection_mappings,
  })
end

--- Open picker with a list of tags.
---
---@param tags string[]
---@param opts { prompt_title: string|?, callback: fun(tag: string, ...: string), allow_multiple: boolean|?, no_default_mappings: boolean|? }|? Options.
---
--- Options:
---  `prompt_title`: Title for the prompt window.
---  `callback`: Callback to run with the selected tag(s).
---  `allow_multiple`: Allow multiple selections to pass to the callback.
---  `no_default_mappings`: Don't apply picker's default mappings.
Picker.pick_tag = function(self, tags, opts)
  self.calling_bufnr = vim.api.nvim_get_current_buf()

  opts = opts or {}

  local selection_mappings
  if not opts.no_default_mappings then
    selection_mappings = self:_tag_selection_mappings()
  end

  self:pick(tags, {
    prompt_title = opts.prompt_title or "Tags",
    callback = opts.callback,
    allow_multiple = opts.allow_multiple,
    no_default_mappings = opts.no_default_mappings,
    selection_mappings = selection_mappings,
  })
end

--------------------------------
--- Concrete helper methods. ---
--------------------------------

---@param key string|?
---@return boolean
local function key_is_set(key)
  if key ~= nil and string.len(key) > 0 then
    return true
  else
    return false
  end
end

--- Get query mappings to use for `find_notes()` or `grep_notes()`.
---@return obsidian.PickerMappingTable
Picker._note_query_mappings = function(self)
  ---@type obsidian.PickerMappingTable
  local mappings = {}

  if self.client.opts.picker.note_mappings and key_is_set(self.client.opts.picker.note_mappings.new) then
    mappings[self.client.opts.picker.note_mappings.new] = {
      desc = "new",
      callback = function(query)
        self.client:command("ObsidianNew", { args = query })
      end,
    }
  end

  return mappings
end

--- Get selection mappings to use for `find_notes()` or `grep_notes()`.
---@return obsidian.PickerMappingTable
Picker._note_selection_mappings = function(self)
  ---@type obsidian.PickerMappingTable
  local mappings = {}

  if self.client.opts.picker.note_mappings and key_is_set(self.client.opts.picker.note_mappings.insert_link) then
    mappings[self.client.opts.picker.note_mappings.insert_link] = {
      desc = "insert link",
      callback = function(note_or_path)
        ---@type obsidian.Note
        local note
        if Note.is_note_obj(note_or_path) then
          note = note_or_path
        else
          note = Note.from_file(note_or_path)
        end
        local link = self.client:format_link(note, {})
        vim.api.nvim_put({ link }, "", false, true)
        self.client:update_ui()
      end,
    }
  end

  return mappings
end

--- Get selection mappings to use for `pick_tag()`.
---@return obsidian.PickerMappingTable
Picker._tag_selection_mappings = function(self)
  ---@type obsidian.PickerMappingTable
  local mappings = {}

  if self.client.opts.picker.tag_mappings then
    if key_is_set(self.client.opts.picker.tag_mappings.tag_note) then
      mappings[self.client.opts.picker.tag_mappings.tag_note] = {
        desc = "tag note",
        callback = function(...)
          local tags = { ... }

          local note = self.client:current_note(self.calling_bufnr)
          if not note then
            log.warn("'%s' is not a note in your workspace", vim.api.nvim_buf_get_name(self.calling_bufnr))
            return
          end

          -- Add the tag and save the new frontmatter to the buffer.
          local tags_added = {}
          local tags_not_added = {}
          for _, tag in ipairs(tags) do
            if note:add_tag(tag) then
              table.insert(tags_added, tag)
            else
              table.insert(tags_not_added, tag)
            end
          end

          if #tags_added > 0 then
            if self.client:update_frontmatter(note, self.calling_bufnr) then
              log.info("Added tags %s to frontmatter", tags_added)
            else
              log.warn "Frontmatter unchanged"
            end
          end

          if #tags_not_added > 0 then
            log.warn("Note already has tags %s", tags_not_added)
          end
        end,
        fallback_to_query = true,
        keep_open = true,
        allow_multiple = true,
      }
    end

    if key_is_set(self.client.opts.picker.tag_mappings.insert_tag) then
      mappings[self.client.opts.picker.tag_mappings.insert_tag] = {
        desc = "insert tag",
        callback = function(tag)
          vim.api.nvim_put({ "#" .. tag }, "", false, true)
        end,
        fallback_to_query = true,
      }
    end
  end

  return mappings
end

---@param opts { prompt_title: string, query_mappings: obsidian.PickerMappingTable|?, selection_mappings: obsidian.PickerMappingTable|? }|?
---@return string
---@diagnostic disable-next-line: unused-local
Picker._build_prompt = function(self, opts)
  opts = opts or {}

  ---@type string
  local prompt = opts.prompt_title or "Find"
  prompt = prompt .. " | <CR> confirm"

  if opts.query_mappings then
    local keys = vim.tbl_keys(opts.query_mappings)
    table.sort(keys)
    for _, key in ipairs(keys) do
      local mapping = opts.query_mappings[key]
      prompt = prompt .. " | " .. key .. " " .. mapping.desc
    end
  end

  if opts.selection_mappings then
    local keys = vim.tbl_keys(opts.selection_mappings)
    table.sort(keys)
    for _, key in ipairs(keys) do
      local mapping = opts.selection_mappings[key]
      prompt = prompt .. " | " .. key .. " " .. mapping.desc
    end
  end

  return prompt
end

---@param entry obsidian.PickerEntry
---
---@return string, { [1]: { [1]: integer, [2]: integer }, [2]: string }[]
---@diagnostic disable-next-line: unused-local
Picker._make_display = function(self, entry)
  ---@type string
  local display = ""
  ---@type { [1]: { [1]: integer, [2]: integer }, [2]: string }[]
  local highlights = {}

  if entry.filename ~= nil then
    local icon, icon_hl
    if entry.icon then
      icon = entry.icon
      icon_hl = entry.icon_hl
    else
      icon, icon_hl = util.get_icon(entry.filename)
    end

    if icon ~= nil then
      display = display .. icon .. " "
      if icon_hl ~= nil then
        highlights[#highlights + 1] = { { 0, strings.strdisplaywidth(icon) }, icon_hl }
      end
    end

    display = display .. tostring(self.client:vault_relative_path(entry.filename, { strict = true }))

    if entry.lnum ~= nil then
      display = display .. ":" .. entry.lnum

      if entry.col ~= nil then
        display = display .. ":" .. entry.col
      end
    end

    if entry.display ~= nil then
      display = display .. ":" .. entry.display
    end
  elseif entry.display ~= nil then
    if entry.icon ~= nil then
      display = entry.icon .. " "
    end
    display = display .. entry.display
  else
    if entry.icon ~= nil then
      display = entry.icon .. " "
    end
    display = display .. tostring(entry.value)
  end

  return assert(display), highlights
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
