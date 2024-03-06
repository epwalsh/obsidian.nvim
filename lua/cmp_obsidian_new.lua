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

  ---@type obsidian.note.HeaderAnchor|?
  local anchor
  if anchor_link then
    anchor = { anchor = anchor_link, header = string.sub(anchor_link, 2), level = 1, line = 1 }
  end

  local new_note = client:create_note { title = search, no_write = true }

  if not new_note.title or string.len(new_note.title) == 0 then
    return
  end

  assert(new_note.path)

  ---@type obsidian.config.LinkStyle, string, string
  local link_style, sort_text
  if ref_type == completion.RefType.Wiki then
    link_style = LinkStyle.wiki
    sort_text = "[[" .. search
  elseif ref_type == completion.RefType.Markdown then
    link_style = LinkStyle.markdown
    sort_text = "[" .. search
  else
    error "not implemented"
  end

  local new_text = client:format_link(new_note, { link_style = link_style, anchor = anchor })
  local label = "Create: " .. new_text

  local items = {
    {
      sortText = sort_text,
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
      },
    },
  }

  return callback {
    items = items,
    isIncomplete = true,
  }
end

source.execute = function(_, item, callback)
  local client = assert(obsidian.get_client())
  local data = item.data
  client:write_note(data.note)
  return callback {}
end

return source
