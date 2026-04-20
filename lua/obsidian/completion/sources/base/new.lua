local abc = require "obsidian.abc"
local completion = require "obsidian.completion.refs"
local obsidian = require "obsidian"
local util = require "obsidian.util"
local LinkStyle = require("obsidian.config").LinkStyle
local Note = require "obsidian.note"
local Path = require "obsidian.path"

---Used to track variables that are used between reusable method calls. This is required, because each
---call to the sources's completion hook won't create a new source object, but will reuse the same one.
---@class obsidian.completion.sources.base.NewNoteSourceCompletionContext : obsidian.ABC
---@field client obsidian.Client
---@field completion_resolve_callback (fun(self: any)) blink or nvim_cmp completion resolve callback
---@field request obsidian.completion.sources.base.Request
---@field search string|?
---@field insert_start integer|?
---@field insert_end integer|?
---@field ref_type obsidian.completion.RefType|?
local NewNoteSourceCompletionContext = abc.new_class()

NewNoteSourceCompletionContext.new = function()
  return NewNoteSourceCompletionContext.init()
end

---@class obsidian.completion.sources.base.NewNoteSourceBase : obsidian.ABC
---@field incomplete_response table
---@field complete_response table
local NewNoteSourceBase = abc.new_class()

---@return obsidian.completion.sources.base.NewNoteSourceBase
NewNoteSourceBase.new = function()
  return NewNoteSourceBase.init()
end

NewNoteSourceBase.get_trigger_characters = completion.get_trigger_characters

---Sets up a new completion context that is used to pass around variables between completion source methods
---@param completion_resolve_callback (fun(self: any)) blink or nvim_cmp completion resolve callback
---@param request obsidian.completion.sources.base.Request
---@return obsidian.completion.sources.base.NewNoteSourceCompletionContext
function NewNoteSourceBase:new_completion_context(completion_resolve_callback, request)
  local completion_context = NewNoteSourceCompletionContext.new()

  -- Sets up the completion callback, which will be called when the (possibly incomplete) completion items are ready
  completion_context.completion_resolve_callback = completion_resolve_callback

  -- This request object will be used to determine the current cursor location and the text around it
  completion_context.request = request

  completion_context.client = assert(obsidian.get_client())

  return completion_context
end

--- Runs a generalized version of the complete (nvim_cmp) or get_completions (blink) methods
---@param cc obsidian.completion.sources.base.NewNoteSourceCompletionContext
function NewNoteSourceBase:process_completion(cc)
  if not self:can_complete_request(cc) then
    return
  end

  ---@type string|?
  local block_link
  cc.search, block_link = util.strip_block_links(cc.search)

  ---@type string|?
  local anchor_link
  cc.search, anchor_link = util.strip_anchor_links(cc.search)

  -- If block link is incomplete, do nothing.
  if not block_link and vim.endswith(cc.search, "#^") then
    cc.completion_resolve_callback(self.incomplete_response)
    return
  end

  -- If anchor link is incomplete, do nothing.
  if not anchor_link and vim.endswith(cc.search, "#") then
    cc.completion_resolve_callback(self.incomplete_response)
    return
  end

  -- Probably just a block/anchor link within current note.
  if string.len(cc.search) == 0 then
    cc.completion_resolve_callback(self.incomplete_response)
    return
  end

  -- Create a mock block.
  ---@type obsidian.note.Block|?
  local block
  if block_link then
    block = { block = "", id = util.standardize_block(block_link), line = 1 }
  end

  -- Create a mock anchor.
  ---@type obsidian.note.HeaderAnchor|?
  local anchor
  if anchor_link then
    anchor = { anchor = anchor_link, header = string.sub(anchor_link, 2), level = 1, line = 1 }
  end

  ---@type { label: string, note: obsidian.Note, template: string|? }[]
  local new_notes_opts = {}

  local note = cc.client:create_note { title = cc.search, no_write = true }
  if note.title and string.len(note.title) > 0 then
    new_notes_opts[#new_notes_opts + 1] = { label = cc.search, note = note }
  end

  -- Check for datetime macros.
  for _, dt_offset in ipairs(util.resolve_date_macro(cc.search)) do
    if dt_offset.cadence == "daily" then
      note = cc.client:daily(dt_offset.offset, { no_write = true })
      if not note:exists() then
        new_notes_opts[#new_notes_opts + 1] =
          { label = dt_offset.macro, note = note, template = cc.client.opts.daily_notes.template }
      end
    end
  end

  -- Completion items.
  local items = {}

  for _, new_note_opts in ipairs(new_notes_opts) do
    local new_note = new_note_opts.note

    assert(new_note.path)

    ---@type obsidian.config.LinkStyle, string
    local link_style, label
    if cc.ref_type == completion.RefType.Wiki then
      link_style = LinkStyle.wiki
      label = string.format("[[%s]] (create)", new_note_opts.label)
    elseif cc.ref_type == completion.RefType.Markdown then
      link_style = LinkStyle.markdown
      label = string.format("[%s](…) (create)", new_note_opts.label)
    else
      error "not implemented"
    end

    local new_text = cc.client:format_link(new_note, { link_style = link_style, anchor = anchor, block = block })
    local documentation = {
      kind = "markdown",
      value = new_note:display_info {
        label = "Create: " .. new_text,
      },
    }

    items[#items + 1] = {
      documentation = documentation,
      sortText = new_note_opts.label,
      label = label,
      kind = vim.lsp.protocol.CompletionItemKind.Reference,
      textEdit = {
        newText = new_text,
        range = {
          start = {
            line = cc.request.context.cursor.row - 1,
            character = cc.insert_start,
          },
          ["end"] = {
            line = cc.request.context.cursor.row - 1,
            character = cc.insert_end,
          },
        },
      },
      data = {
        note = new_note,
        template = new_note_opts.template,
      },
    }
  end

  cc.completion_resolve_callback(vim.tbl_deep_extend("force", self.complete_response, { items = items }))
end

--- Returns whatever it's possible to complete the search and sets up the search related variables in cc
---@param cc obsidian.completion.sources.base.NewNoteSourceCompletionContext
---@return boolean success provides a chance to return early if the request didn't meet the requirements
function NewNoteSourceBase:can_complete_request(cc)
  local can_complete
  can_complete, cc.search, cc.insert_start, cc.insert_end, cc.ref_type = completion.can_complete(cc.request)

  if cc.search ~= nil then
    cc.search = util.lstrip_whitespace(cc.search)
  end

  if not (can_complete and cc.search ~= nil and #cc.search >= cc.client.opts.completion.min_chars) then
    cc.completion_resolve_callback(self.incomplete_response)
    return false
  end
  return true
end

--- Runs a generalized version of the execute method
---@param item any
---@return table|? callback_return_value
function NewNoteSourceBase:process_execute(item)
  local client = assert(obsidian.get_client())
  local data = item.data

  if data == nil then
    return nil
  end

  -- Make sure `data.note` is actually an `obsidian.Note` object. If it gets serialized at some
  -- point (seems to happen on Linux), it will lose its metatable.
  if not Note.is_note_obj(data.note) then
    data.note = setmetatable(data.note, Note.mt)
    data.note.path = setmetatable(data.note.path, Path.mt)
  end

  client:write_note(data.note, { template = data.template })
  return {}
end

return NewNoteSourceBase
