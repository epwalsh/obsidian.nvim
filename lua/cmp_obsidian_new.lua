local abc = require "obsidian.abc"
local completion = require "obsidian.completion.refs"
local obsidian = require "obsidian"
local log = require "obsidian.log"
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

  ---@type string|Path|?
  local dir
  if client.opts.completion.new_notes_location == nil then
    dir = nil -- let the client decide
  elseif client.opts.completion.new_notes_location == "notes_subdir" then
    dir = client.dir
    if client.opts.notes_subdir ~= nil then
      dir = dir / client.opts.notes_subdir
    end
  elseif client.opts.completion.new_notes_location == "current_dir" then
    dir = vim.fn.expand "%:p:h"
  else
    log.err "Bad option value for 'completion.new_notes_location'. Skipping creating new note."
    return
  end

  if can_complete and search ~= nil and #search >= client.opts.completion.min_chars then
    local new_title, new_id, path
    new_id = client:new_note_id(search)
    new_title, new_id, path = client:parse_title_id_path(search, new_id, dir)

    if not new_title or string.len(new_title) == 0 then
      return
    end

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

    local new_text = client:format_link(tostring(path), { label = new_title, link_style = link_style, id = new_id })
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
          id = new_id,
          title = search,
          dir = dir,
        },
      },
    }

    return callback {
      items = items,
      isIncomplete = true,
    }
  else
    return callback { isIncomplete = true }
  end
end

source.execute = function(_, item, callback)
  local client = assert(obsidian.get_client())
  local data = item.data
  client:new_note(data.title, data.id, data.dir)
  return callback {}
end

return source
