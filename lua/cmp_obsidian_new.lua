local completion = require "obsidian.completion"
local obsidian = require "obsidian"
local config = require "obsidian.config"

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
    table.insert(items, {
      sortText = "[[" .. search,
      label = "Create: [[" .. new_id .. "|" .. search .. "]]",
      kind = 18,
      textEdit = {
        newText = "[[" .. new_id .. "|" .. search .. "]]",
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
  local client = obsidian.new(data.opts)
  local dir = vim.fn.expand "%:p:h"
  if client.opts.never_current_dir then
    dir = nil
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
