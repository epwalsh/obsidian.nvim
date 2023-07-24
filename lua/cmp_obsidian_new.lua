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
  local can_complete, search, insert_start, insert_end = completion.can_complete(request)

  if can_complete and search ~= nil and #search >= opts.completion.min_chars then
    local new_id = client:new_note_id(search)
    local items = {}
    local new_title = search
    if new_id ~= "" and new_id ~= nil then
        new_title = new_id .. "|" .. search
    end
    table.insert(items, {
      sortText = "[[" .. search,
      label = "Create: [[" .. new_title .. "]]",
      kind = 18,
      textEdit = {
        newText = "[[" .. new_title .. "]]",
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
      },
    })
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
    echo.error(
      "Bad option value for 'completion.new_notes_location'. Skipping creating new note.",
      client.opts.log_level
    )
    return
  end

  client:new_note(data.title, data.id, dir)
  return callback {}
end

---Get opts.
---
---@return obsidian.config.ClientOpts
source.option = function(_, params)
  return config.ClientOpts.normalize(params.option)
end

return source
