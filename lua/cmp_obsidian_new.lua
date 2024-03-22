local abc = require "obsidian.abc"
local completion = require "obsidian.completion.refs"
local obsidian = require "obsidian"
local util = require "obsidian.util"
local LinkStyle = require("obsidian.config").LinkStyle

---@class cmp_obsidian_new.Source : obsidian.ABC
local source = abc.new_class()

source.new = function()
  return source.init()
end

source.get_trigger_characters = completion.get_trigger_characters

source.get_keyword_pattern = completion.get_keyword_pattern

source.complete = function(_, request, callback)
  local client = assert(obsidian.get_client())
  local can_complete, search, insert_start, insert_end, ref_type = completion.can_complete(request)

  if search ~= nil then
    search = util.lstrip_whitespace(search)
  end

  if not (can_complete and search ~= nil and #search >= client.opts.completion.min_chars) then
    callback { isIncomplete = true }
    return
  end

  ---@type string|?
  local block_link
  search, block_link = util.strip_block_links(search)

  ---@type string|?
  local anchor_link
  search, anchor_link = util.strip_anchor_links(search)

  -- If block link is incomplete, do nothing.
  if not block_link and vim.endswith(search, "#^") then
    callback { isIncomplete = true }
    return
  end

  -- If anchor link is incomplete, do nothing.
  if not anchor_link and vim.endswith(search, "#") then
    callback { isIncomplete = true }
    return
  end

  -- Probably just a block/anchor link within current note.
  if string.len(search) == 0 then
    callback { isIncomplete = false }
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

  local note = client:create_note { title = search, no_write = true }
  if note.title and string.len(note.title) > 0 then
    new_notes_opts[#new_notes_opts + 1] = { label = search, note = note }
  end

  -- Check for datetime macros.
  for _, dt_offset in ipairs(util.resolve_date_macro(search)) do
    if dt_offset.cadence == "daily" then
      note = client:daily(dt_offset.offset, { no_write = true })
      if not note:exists() then
        new_notes_opts[#new_notes_opts + 1] =
          { label = dt_offset.macro, note = note, template = client.opts.daily_notes.template }
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
    if ref_type == completion.RefType.Wiki then
      link_style = LinkStyle.wiki
      label = string.format("[[%s]] (create)", new_note_opts.label)
    elseif ref_type == completion.RefType.Markdown then
      link_style = LinkStyle.markdown
      label = string.format("[%s](…) (create)", new_note_opts.label)
    else
      error "not implemented"
    end

    local new_text = client:format_link(new_note, { link_style = link_style, anchor = anchor, block = block })
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
      kind = 18,
      textEdit = {
        newText = new_text,
        range = {
          start = {
            line = request.context.cursor.row - 1,
            character = insert_start,
          },
          ["end"] = {
            line = request.context.cursor.row - 1,
            character = insert_end,
          },
        },
      },
      data = {
        note = new_note,
        template = new_note_opts.template,
      },
    }
  end

  return callback {
    items = items,
    isIncomplete = true,
  }
end

source.execute = function(_, item, callback)
  local Note = require "obsidian.note"
  local Path = require "obsidian.path"

  local client = assert(obsidian.get_client())
  local data = item.data

  -- Make sure `data.note` is actually an `obsidian.Note` object. If it gets serialized at some
  -- point (seems to happen on Linux), it will lose its metatable.
  if not Note.is_note_obj(data.note) then
    data.note = setmetatable(data.note, Note.mt)
    data.note.path = setmetatable(data.note.path, Path.mt)
  end

  client:write_note(data.note, { template = data.template })
  return callback {}
end

return source
