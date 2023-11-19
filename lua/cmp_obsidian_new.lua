local Path = require "plenary.path"

local completion = require "obsidian.completion"
local obsidian = require "obsidian"
local config = require "obsidian.config"
local echo = require "obsidian.echo"

local source = {}

source.new = function()
  return setmetatable({}, { __index = source })
end

source.get_trigger_characters = completion.get_trigger_characters

source.get_keyword_pattern = completion.get_keyword_pattern

source.complete = function(self, request, callback)
  local opts = self:option(request)
  local client = obsidian.new(opts)
  local can_complete, search, insert_start, insert_end, ref_type = completion.can_complete(request)

  ---@type string|Path|?
  local dir
  if client.opts.completion.new_notes_location == nil then
    dir = nil -- let the client decide
  elseif client.opts.completion.new_notes_location == "notes_subdir" then
    dir = Path:new(client.opts.dir)
    if client.opts.notes_subdir ~= nil then
      dir = dir / client.opts.notes_subdir
    end
  elseif client.opts.completion.new_notes_location == "current_dir" then
    dir = vim.fn.expand "%:p:h"
  else
    echo.err "Bad option value for 'completion.new_notes_location'. Skipping creating new note."
    return
  end

  if can_complete and search ~= nil and #search >= opts.completion.min_chars then
    local new_title, new_id, path, rel_path
    new_id = client:new_note_id(search)
    new_title, new_id, path = client:parse_title_id_path(search, new_id, dir)
    rel_path = assert(client:vault_relative_path(path))
    if vim.endswith(rel_path, ".md") then
      rel_path = string.sub(rel_path, 1, -4)
    end

    ---@type string, string
    local sort_text, label, new_text
    if ref_type == completion.RefType.Wiki then
      if opts.completion.use_path_only then
        new_title = rel_path
      elseif opts.completion.prepend_note_path then
        new_title = rel_path .. "|" .. new_title
      elseif opts.completion.prepend_note_id then
        new_title = new_id .. "|" .. new_title
      else
        echo.err "Invalid completion options"
        return
      end
      sort_text = "[[" .. search
      label = "Create: [[" .. new_title .. "]]"
      new_text = "[[" .. new_title .. "]]"
    elseif ref_type == completion.RefType.Markdown then
      sort_text = "[" .. search
      label = "Create: [" .. new_title .. "](" .. rel_path .. ".md)"
      new_text = "[" .. new_title .. "](" .. rel_path .. ".md)"
    else
      error "not implemented"
    end

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
          opts = opts,
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
  local data = item.data
  ---@type obsidian.Client
  local client = obsidian.new(data.opts)

  client:new_note(data.title, data.id, data.dir)
  return callback {}
end

---Get opts.
---
---@return obsidian.config.ClientOpts
source.option = function(_, params)
  return config.ClientOpts.normalize(params.option)
end

return source
